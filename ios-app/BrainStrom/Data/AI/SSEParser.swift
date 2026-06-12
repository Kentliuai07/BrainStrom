import Foundation

// ============================================================
// SSE 解析 —— 後端裁決：沒有 event: 行，每事件一行 data: {JSON}\n\n，
// type 在 JSON 裡。流程：逐行掃 data: 前綴 → 累積 → 空行/結束時 JSON.parse
// → 依 JSON.type 分發成 AIEvent。
// ============================================================

/// 行累積器：逐行餵入，遇空行（或結束 flush）吐出完整的 data JSON 字串。
struct SSEAccumulator {
    private var dataLines: [String] = []

    /// 餵一行；遇空行回傳累積的 data JSON 字串（無資料則 nil）。
    mutating func feed(line: String) -> String? {
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix(":") { return nil }           // 註解/心跳
        if line.hasPrefix("data:") {
            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
        }
        // event:/id: 等行一律忽略（後端不用 event: 行）
        return nil
    }

    /// 串流結束時呼叫：若還有未吐出的 data（無結尾空行）也補吐。
    mutating func flush() -> String? {
        guard !dataLines.isEmpty else { return nil }
        let joined = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        return joined.isEmpty ? nil : joined
    }
}

/// data JSON 字串 → 領域事件。
enum SSEEventMapper {

    static func map(jsonString: String) -> AIEvent? {
        guard let data = jsonString.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return map(object)
    }

    static func map(_ object: [String: Any]) -> AIEvent? {
        guard let type = object["type"] as? String else { return nil }

        switch type {
        case "delta":
            let text = (object["text"] as? String) ?? ""
            return text.isEmpty ? nil : .delta(text)

        case "usage":
            return .usage(AIUsage(
                inputTokens: intValue(object["input_tokens"]),
                outputTokens: intValue(object["output_tokens"]),
                cacheReadInputTokens: intValue(object["cache_read_input_tokens"]),
                model: (object["model"] as? String) ?? ""
            ))

        case "progress":
            return .progress(
                current: intValue(object["current"]),
                total: intValue(object["total"]),
                message: object["message"] as? String
            )

        case "card_start":
            // ⚠ 契約 card_start.type 與事件 discriminator "type" 撞名（同一扁平物件無法並存）；
            // 先用備援鍵 cardType，否則留空，待後端澄清實際鍵名。
            return .cardStart(
                index: intValue(object["index"]),
                title: (object["title"] as? String) ?? "",
                type: (object["cardType"] as? String) ?? ""
            )

        case "card_done":
            guard let card = object["card"] as? [String: Any] else { return nil }
            return .cardDone(index: intValue(object["index"]), card: cardPayload(card))

        case "card_removed":
            guard let cardId = (object["cardId"] as? String) ?? (object["card_id"] as? String) else { return nil }
            return .cardRemoved(cardId: cardId)

        case "proposal":
            let items = (object["items"] as? [[String: Any]]) ?? []
            let parsed = items.compactMap { item -> ProposalItem? in
                guard let action = item["action"] as? String,
                      let label = item["label"] as? String else { return nil }
                let args = item["args"] as? [String: Any]
                return ProposalItem(action: action, label: label, instruction: args?["instruction"] as? String)
            }
            return parsed.isEmpty ? nil : .proposal(parsed)

        case "done":
            return .done

        case "error":
            return .error(
                code: (object["code"] as? String) ?? "unknown",
                message: (object["error"] as? String) ?? (object["detail"] as? String) ?? ""
            )

        default:
            // 真後端 structure 雙軌容錯：每張卡的「開始」事件 type 是卡片型別名而非 "card_start"
            // （後端 card_start 修正部署前的實際 wire 格式）。有 index+title 即視為 card_start。
            if object["index"] != nil, let title = object["title"] as? String {
                return .cardStart(index: intValue(object["index"]), title: title, type: type)
            }
            return nil   // 其餘未知事件：容忍前進，不炸
        }
    }

    private static func cardPayload(_ card: [String: Any]) -> CardPayload {
        CardPayload(
            action: card["action"] as? String,
            id: card["id"] as? String,
            type: card["type"] as? String,
            title: card["title"] as? String,
            content: card["content"] as? String,
            position: card["position"] as? Int,
            absorbed: (card["absorbed"] as? [String]) ?? []
        )
    }

    /// JSON 數字可能解成 Int / Double / NSNumber，統一取 Int。
    private static func intValue(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
}
