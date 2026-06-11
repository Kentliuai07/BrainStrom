import Foundation

// ============================================================
// AI 服務 · 真後端實作 —— brainstrom-ai（Fly.io）
// POST + Bearer + text/event-stream
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

    func optimize(_ payload: NotePayload, options: OptimizeOptions) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let note: NotePayload
            let splitTopics: Bool
            let addHeadings: Bool
            let proofread: Bool
        }
        return stream(path: "ai/optimize", body: Body(
            note: payload,
            splitTopics: options.splitTopics,
            addHeadings: options.addHeadings,
            proofread: options.proofread
        ))
    }

    func structure(_ payload: NotePayload) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let note: NotePayload
        }
        return stream(path: "ai/structure", body: Body(note: payload))
    }

    func chat(messages: [ChatMessage], context: NotePayload?) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let messages: [ChatMessage]
            let note: NotePayload?
        }
        return stream(path: "ai/chat", body: Body(messages: messages, note: context))
    }

    func search(query: String) -> AsyncThrowingStream<AIEvent, any Error> {
        struct Body: Encodable {
            let query: String
        }
        return stream(path: "ai/search", body: Body(query: query))
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
                        continuation.yield(.error(message: String(localized: "伺服器回應 \(http.statusCode)，請稍後再試。")))
                        continuation.finish()
                        return
                    }

                    var accumulator = SSEAccumulator()
                    var lineBuffer: [UInt8] = []

                    for try await byte in bytes {
                        guard !Task.isCancelled else { break }
                        if byte == 0x0A {  // \n
                            var line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)
                            if line.hasSuffix("\r") { line.removeLast() }
                            if let message = accumulator.feed(line: line),
                               let event = SSEEventMapper.map(message) {
                                continuation.yield(event)
                                if case .done = event {
                                    continuation.finish()
                                    return
                                }
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
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
}
