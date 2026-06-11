import Foundation

// ============================================================
// SSE 解析 —— text/event-stream 行協議 → AIEvent
// 事件名照阶段二文档 §2.1：delta/done/error/usage/
// card_start/card_done/card_removed/progress/hit_list
// ============================================================

/// 一則完整 SSE 訊息。
struct SSEMessage: Equatable, Sendable {
    let event: String?
    let data: String
}

/// 行累積器：逐行餵入，遇空行吐出完整訊息（單一 Task 內使用）。
struct SSEAccumulator {
    private var eventName: String?
    private var dataLines: [String] = []

    mutating func feed(line: String) -> SSEMessage? {
        if line.isEmpty {
            guard eventName != nil || !dataLines.isEmpty else { return nil }
            let message = SSEMessage(event: eventName, data: dataLines.joined(separator: "\n"))
            eventName = nil
            dataLines = []
            return message
        }
        if line.hasPrefix(":") { return nil }  // 註解/心跳
        if line.hasPrefix("event:") {
            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}

/// SSE 訊息 → 領域事件 的對應。
enum SSEEventMapper {

    static func map(_ message: SSEMessage) -> AIEvent? {
        let object = (try? JSONSerialization.jsonObject(with: Data(message.data.utf8))) as? [String: Any]

        switch message.event {
        case "delta", nil:
            let text = (object?["text"] as? String) ?? message.data
            return text.isEmpty ? nil : .delta(text)

        case "done":
            return .done

        case "error":
            let detail = (object?["detail"] as? String)
                ?? (object?["error"] as? String)
                ?? message.data
            return .error(message: detail)

        case "usage":
            return .usage(
                inputTokens: (object?["input_tokens"] as? Int) ?? 0,
                outputTokens: (object?["output_tokens"] as? Int) ?? 0
            )

        case "card_start":
            guard let id = object?["id"] as? String else { return nil }
            return .cardStart(id: id, title: (object?["title"] as? String) ?? "")

        case "card_done":
            guard let id = object?["id"] as? String else { return nil }
            return .cardDone(id: id)

        case "card_removed":
            guard let id = object?["id"] as? String else { return nil }
            return .cardRemoved(id: id)

        case "progress":
            let value = (object?["value"] as? Double) ?? Double(message.data) ?? 0
            return .progress(min(max(value, 0), 1))

        case "hit_list":
            guard let array = object?["hits"] as? [[String: Any]] else { return nil }
            let hits = array.compactMap { item -> SearchHit? in
                guard let id = item["id"] as? String,
                      let title = item["title"] as? String else { return nil }
                return SearchHit(id: id, title: title, systemName: (item["system"] as? String) ?? "")
            }
            return .hitList(hits)

        default:
            return nil  // 未知事件：容忍前進，不炸
        }
    }
}
