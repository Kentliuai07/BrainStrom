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
