import Foundation

// ============================================================
// AI 服務 · 開發替身 —— 不打網路，照 §2.1 事件時序演出
// 用途：畫面開發、#Preview、無網測試
// ============================================================

struct AIServiceStub: AIServicing {

    /// 每個 delta 之間的延遲（秒），模擬串流節奏。
    var deltaInterval: Duration = .milliseconds(80)

    func health() async -> Bool { true }

    func optimize(_ payload: NotePayload, options: OptimizeOptions) -> AsyncThrowingStream<AIEvent, any Error> {
        canned(deltas: [
            "## 研究動機\n",
            "這學期想做「城市裡的微氣候」。",
            "先從通學路線的溫差開始記錄，",
            "捷運站出口、騎樓下、公園樹蔭，",
            "每天同一時間量三次。\n\n",
            "## 觀測計畫\n",
            "三條路線、各 30 個樣本，",
            "完成後對照綠覆率資料。",
        ], withProgress: true)
    }

    func structure(_ payload: NotePayload) -> AsyncThrowingStream<AIEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let cards: [(String, String)] = [
                        ("stub-card-1", "核心問題"),
                        ("stub-card-2", "觀測方法"),
                        ("stub-card-3", "樣本統計"),
                    ]
                    for (index, card) in cards.enumerated() {
                        continuation.yield(.cardStart(id: card.0, title: card.1))
                        try await Task.sleep(for: .milliseconds(500))
                        continuation.yield(.cardDone(id: card.0))
                        continuation.yield(.progress(Double(index + 1) / Double(cards.count)))
                    }
                    continuation.yield(.usage(inputTokens: 820, outputTokens: 410))
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func chat(messages: [ChatMessage], context: NotePayload?) -> AsyncThrowingStream<AIEvent, any Error> {
        canned(deltas: [
            "看了你的觀測表：",
            "河堤—公園只在週末有紀錄。",
            "平日 17:00 後天色變暗，你大概都跳過了。",
            "建議改成早上通學前量，",
            "或把這條線改隔日一次。",
        ], withProgress: false)
    }

    func search(query: String) -> AsyncThrowingStream<AIEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    continuation.yield(.hitList([
                        SearchHit(id: "stub-note-1", title: "期末報告構想", systemName: "期末報告"),
                        SearchHit(id: "stub-note-2", title: "觀測日誌 #4", systemName: "期末報告"),
                    ]))
                    for chunk in ["你在 6/9 的觀測裡記到：", "騎樓下比路面平均低 3.2°C，", "下午差距最大。"] {
                        try await Task.sleep(for: deltaInterval)
                        continuation.yield(.delta(chunk))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - 共通罐頭流

    private func canned(deltas: [String], withProgress: Bool) -> AsyncThrowingStream<AIEvent, any Error> {
        let interval = deltaInterval
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for (index, chunk) in deltas.enumerated() {
                        try await Task.sleep(for: interval)
                        continuation.yield(.delta(chunk))
                        if withProgress {
                            continuation.yield(.progress(Double(index + 1) / Double(deltas.count)))
                        }
                    }
                    continuation.yield(.usage(inputTokens: 512, outputTokens: 256))
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
