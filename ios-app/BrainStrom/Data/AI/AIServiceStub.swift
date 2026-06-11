import Foundation

// ============================================================
// AI 服務 · 開發替身 —— 不打網路，照《契約 §2》事件時序演出
// 用途：畫面開發、#Preview、無網測試
// ============================================================

struct AIServiceStub: AIServicing {

    /// 每個 delta 之間的延遲（秒），模擬串流節奏。
    var deltaInterval: Duration = .milliseconds(80)

    func health() async -> Bool { true }

    func chatNote(messages: [ChatMessage], note: NotePayload, kickoff: Bool) -> AsyncThrowingStream<AIEvent, any Error> {
        let deltas = kickoff
            ? ["看了你寫的「\(note.title)」：", "方向不錯，先想清楚要解決誰的什麼問題。", "我幫你列了幾個可以馬上動手的點。"]
            : ["看了你的觀測表：", "河堤—公園只在週末有紀錄。", "建議改成早上通學前量，或這條線改隔日一次。"]
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for chunk in deltas {
                        try await Task.sleep(for: deltaInterval)
                        continuation.yield(.delta(chunk))
                    }
                    if kickoff {
                        continuation.yield(.proposal([
                            ProposalItem(action: "structure", label: "幫我分卡片", instruction: nil),
                            ProposalItem(action: "edit_text", label: "幫我補開頭", instruction: "幫這則筆記補一段開場"),
                            ProposalItem(action: "find_github", label: "找相關專案", instruction: nil),
                        ]))
                    }
                    continuation.yield(.usage(AIUsage(inputTokens: 512, outputTokens: 256, cacheReadInputTokens: 0, model: "stub")))
                    continuation.yield(.done)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func optimize(note: NotePayload, groupTopics: Bool, instruction: String?) -> AsyncThrowingStream<AIEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let adds: [(Int, String, String)] = [
                        (0, "研究動機", "這學期想做「城市裡的微氣候」，先從通學路線的溫差開始記錄。"),
                        (1, "觀測計畫", "三條路線、各 30 個樣本，完成後對照綠覆率資料。"),
                    ]
                    for (i, title, content) in adds {
                        try await Task.sleep(for: .milliseconds(300))
                        continuation.yield(.cardDone(index: i, card: CardPayload(
                            action: "add", id: nil, type: "heading", title: title, content: content, position: i, absorbed: [])))
                    }
                    continuation.yield(.usage(AIUsage(inputTokens: 640, outputTokens: 300, cacheReadInputTokens: 0, model: "stub")))
                    continuation.yield(.done)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func structure(note: NotePayload) -> AsyncThrowingStream<AIEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let cards: [(String, String)] = [
                        ("核心問題", "城市裡不同地點的微氣候差多少？"),
                        ("觀測方法", "固定時間、三個地點、各量三次。"),
                        ("樣本統計", "三條路線各 30 筆，對照綠覆率。"),
                    ]
                    for (index, card) in cards.enumerated() {
                        continuation.yield(.cardStart(index: index, title: card.0, type: "text"))
                        try await Task.sleep(for: .milliseconds(450))
                        continuation.yield(.cardDone(index: index, card: CardPayload(
                            action: nil, id: nil, type: "text", title: card.0, content: card.1, position: index, absorbed: [])))
                        continuation.yield(.progress(current: index + 1, total: cards.count, message: nil))
                    }
                    continuation.yield(.usage(AIUsage(inputTokens: 820, outputTokens: 410, cacheReadInputTokens: 0, model: "stub")))
                    continuation.yield(.done)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
