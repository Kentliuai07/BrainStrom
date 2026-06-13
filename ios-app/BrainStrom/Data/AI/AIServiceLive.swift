import Foundation

// ============================================================
// AI 服務 · 真後端實作 —— brainstrom-ai（Fly.io）
// POST + Bearer + text/event-stream；路徑/Body 對齊《整合契約 §1》
// ============================================================

struct AIServiceLive: AIServicing {

    let config: AIConfig

    func health() async -> Bool {
        do {
            var request = URLRequest(url: config.baseURL.appending(path: "ai/health"))
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (object?["ok"] as? Bool) ?? false
        } catch {
            return false
        }
    }

    func chatNote(messages: [ChatMessage], note: NotePayload, project: ProjectContext?, mode: String?, kickoff: Bool) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let messages: [ChatMessage]
            let note: NotePayload
            let project: ProjectContext?
            let mode: String?
            let kickoff: Bool
        }
        return stream(path: "ai/chat/note", body: Body(messages: messages, note: note, project: project, mode: mode, kickoff: kickoff))
    }

    func findCompetitors(keywords: String) async throws -> [CompetitorItem] {
        struct Body: Encodable { let keywords: String }
        struct Resp: Decodable { let items: [CompetitorItem] }
        var request = URLRequest(url: config.baseURL.appending(path: "find/competitors"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(keywords: keywords))
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return (try? JSONDecoder().decode(Resp.self, from: data).items) ?? []
    }

    func findSimilar(url: String) async throws -> [CompetitorItem] {
        struct Body: Encodable { let url: String }
        struct Resp: Decodable { let items: [CompetitorItem] }
        var request = URLRequest(url: config.baseURL.appending(path: "find/similar"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(url: url))
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return (try? JSONDecoder().decode(Resp.self, from: data).items) ?? []
    }

    func optimize(note: NotePayload, groupTopics: Bool, instruction: String?) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let note: NotePayload
            let groupTopics: Bool
            let instruction: String?
        }
        return stream(path: "ai/optimize", body: Body(note: note, groupTopics: groupTopics, instruction: instruction))
    }

    func structure(note: NotePayload) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let note: NotePayload
            let mode: String
        }
        return stream(path: "ai/structure", body: Body(note: note, mode: "full"))
    }

    func generatePersonas(appName: String, oneLiner: String, country: String,
                          regenerateIndex: Int?, avoidCards: [PersonaCard], sharedSearch: PersonaSearchBundle?)
        -> AsyncThrowingStream<PersonaEvent, any Error> {
        struct Body: Encodable {
            let appName: String
            let oneLiner: String
            let country: String
            let regenerateIndex: Int?
            let avoidCards: [PersonaCard]
            let sharedSearch: PersonaSearchBundle?
        }
        let body = Body(appName: appName, oneLiner: oneLiner, country: country,
                        regenerateIndex: regenerateIndex, avoidCards: avoidCards, sharedSearch: sharedSearch)
        return streamPersona(body: body)
    }

    // MARK: - SSE 共通管線

    private func stream(path: String, body: some Encodable & Sendable) -> AsyncThrowingStream<AIEvent, any Error> {
        let baseURL = config.baseURL
        let token = config.authToken

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appending(path: path))
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = 120

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        continuation.yield(.error(code: errorCode(for: http.statusCode), message: errorMessage(for: http.statusCode)))
                        continuation.finish()
                        return
                    }

                    var accumulator = SSEAccumulator()
                    var lineBuffer: [UInt8] = []

                    func emit(_ json: String?) -> Bool {  // 回傳 true 表示收到 done，要結束
                        guard let json, let event = SSEEventMapper.map(jsonString: json) else { return false }
                        continuation.yield(event)
                        if case .done = event { return true }
                        return false
                    }

                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        if byte == 0x0A {  // \n
                            var line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)
                            if line.hasSuffix("\r") { line.removeLast() }
                            if emit(accumulator.feed(line: line)) {
                                continuation.finish()
                                return
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    _ = emit(accumulator.flush())  // 收尾：無結尾空行的最後一筆
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Persona 串流管線（专用，映射成 PersonaEvent）

    private func streamPersona(body: some Encodable & Sendable) -> AsyncThrowingStream<PersonaEvent, any Error> {
        let baseURL = config.baseURL
        let token = config.authToken
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appending(path: "ai/personas"))
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = 180
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard http.statusCode == 200 else {
                        continuation.yield(.error(code: errorCode(for: http.statusCode), message: errorMessage(for: http.statusCode)))
                        continuation.finish(); return
                    }
                    var accumulator = SSEAccumulator()
                    var lineBuffer: [UInt8] = []
                    func emit(_ json: String?) -> Bool {
                        guard let json, let event = Self.mapPersona(jsonString: json) else { return false }
                        continuation.yield(event)
                        if case .done = event { return true }
                        return false
                    }
                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        if byte == 0x0A {
                            var line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)
                            if line.hasSuffix("\r") { line.removeLast() }
                            if emit(accumulator.feed(line: line)) { continuation.finish(); return }
                        } else { lineBuffer.append(byte) }
                    }
                    _ = emit(accumulator.flush())
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func mapPersona(jsonString: String) -> PersonaEvent? {
        guard let data = jsonString.data(using: .utf8),
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = o["type"] as? String else { return nil }
        func intv(_ a: Any?) -> Int { (a as? Int) ?? (a as? Double).map(Int.init) ?? (a as? NSNumber)?.intValue ?? 0 }
        func competitors(_ key: String) -> [CompetitorItem] {
            (o[key] as? [[String: Any]] ?? []).map { d in
                CompetitorItem(source: (d["source"] as? String) ?? "web",
                               title: (d["title"] as? String) ?? "",
                               url: (d["url"] as? String) ?? "",
                               subtitle: d["subtitle"] as? String,
                               summary: d["summary"] as? String)
            }
        }
        switch type {
        case "progress": return .progress(message: o["message"] as? String)
        case "search_done":
            return .searchResults(PersonaSearchBundle(
                competitors: competitors("competitors"), articles: competitors("articles"),
                openSource: competitors("openSource"), partial: (o["partial"] as? Bool) ?? false))
        case "card_start": return .cardStart(index: intv(o["index"]))
        case "delta":
            let t = (o["text"] as? String) ?? ""
            return t.isEmpty ? nil : .delta(index: intv(o["index"]), text: t)
        case "card_done":
            guard let card = o["card"] as? [String: Any] else { return nil }
            let pc = PersonaCard(
                oneLiner: (card["oneLiner"] as? String) ?? "", targetUser: (card["targetUser"] as? String) ?? "",
                painPoint: (card["painPoint"] as? String) ?? "", coreValue: (card["coreValue"] as? String) ?? "",
                marketStrategy: (card["marketStrategy"] as? String) ?? "", businessModel: (card["businessModel"] as? String) ?? "",
                coreFeatures: (card["coreFeatures"] as? String) ?? "", tagline: (card["tagline"] as? String) ?? "")
            return .cardDone(index: intv(o["index"]), card: pc)
        case "usage":
            return .usage(AIUsage(inputTokens: intv(o["input_tokens"]), outputTokens: intv(o["output_tokens"]),
                                  cacheReadInputTokens: intv(o["cache_read_input_tokens"]), model: (o["model"] as? String) ?? ""))
        case "done": return .done
        case "error": return .error(code: (o["code"] as? String) ?? "unknown", message: (o["error"] as? String) ?? (o["detail"] as? String) ?? "")
        default: return nil
        }
    }

    private func errorCode(for status: Int) -> String {
        switch status {
        case 401: "unauthorized"
        case 429: "rate_limited"
        case 400: "bad_request"
        default: "http_\(status)"
        }
    }

    private func errorMessage(for status: Int) -> String {
        switch status {
        case 401: String(localized: "登入憑證失效，請重新登入。")
        case 429: String(localized: "AI 暫時忙線，稍等再試")
        case 400: String(localized: "筆記太大，先精簡或拆成兩則")
        default: String(localized: "伺服器回應 \(status)，請稍後再試。")
        }
    }
}
