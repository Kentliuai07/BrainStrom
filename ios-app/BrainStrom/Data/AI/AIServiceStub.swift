import Foundation

// ============================================================
// AI 服務 · 開發替身 —— 不打網路，照《契約 §2》事件時序演出
// 用途：畫面開發、#Preview、無網測試
// ============================================================

struct AIServiceStub: AIServicing {

    /// 每個 delta 之間的延遲（秒），模擬串流節奏。
    var deltaInterval: Duration = .milliseconds(80)

    func health() async -> Bool { true }

    func findCompetitors(keywords: String) async throws -> [CompetitorItem] {
        [CompetitorItem(source: "web", title: "Fitbod", url: "https://apps.apple.com/fitbod", subtitle: "apps.apple.com", summary: "AI 健身排课与重训计画 App"),
         CompetitorItem(source: "article", title: "2024 健身 App 推薦比較", url: "https://example.com/fitness-apps-2024", subtitle: "example.com", summary: "盤點今年熱門健身排課 App 的優缺點"),
         CompetitorItem(source: "github", title: "open/fitness-ai", url: "https://github.com/open/fitness-ai", subtitle: "AI workout planner", summary: "AI 自動重訓計畫開源專案")]
    }

    func findSimilar(url: String) async throws -> [CompetitorItem] {
        [CompetitorItem(source: "web", title: "Strong", url: "https://apps.apple.com/strong", subtitle: "apps.apple.com", summary: "重训纪录与计画 App")]
    }

    func generatePersonas(appName: String, oneLiner: String, country: String,
                          regenerateIndex: Int?, avoidCards: [PersonaCard], sharedSearch: PersonaSearchBundle?)
        -> AsyncThrowingStream<PersonaEvent, any Error> {
        let cards: [PersonaCard] = [
            PersonaCard(oneLiner: "專為小資族設計的極簡記帳 App，30 秒記一筆。", targetUser: "剛出社會的上班族", painPoint: "記帳太麻煩、堅持不了", coreValue: "快到沒有藉口不記", marketStrategy: "免費＋訂閱進階", businessModel: "Freemium 訂閱", coreFeatures: "一鍵記帳、自動分類、週報", tagline: "記帳，就該這麼簡單"),
            PersonaCard(oneLiner: "隱私優先的本地加密記帳，資料只在你手機。", targetUser: "重視隱私的使用者", painPoint: "不想財務資料上雲", coreValue: "本地加密、不上傳", marketStrategy: "一次買斷", businessModel: "買斷制", coreFeatures: "本地加密、離線、匯出", tagline: "你的帳，只有你看得到"),
            PersonaCard(oneLiner: "家庭共用的多人協作記帳平台。", targetUser: "夫妻／室友／家庭", painPoint: "多人共帳很亂", coreValue: "一起記、自動拆帳", marketStrategy: "家庭方案", businessModel: "家庭訂閱", coreFeatures: "共享帳本、拆帳、同步", tagline: "家的帳，一起記才清楚"),
            PersonaCard(oneLiner: "內建 AI 財務教練的智慧記帳。", targetUser: "想存錢卻存不到的人", painPoint: "看不懂自己花去哪", coreValue: "AI 分析＋省錢建議", marketStrategy: "AI 訂閱", businessModel: "AI Premium", coreFeatures: "AI 分析、預算、提醒", tagline: "AI 陪你真的存到錢"),
        ]
        let n = regenerateIndex != nil ? 1 : cards.count
        let interval = deltaInterval
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.progress(message: "開始分析《\(appName.isEmpty ? oneLiner : appName)》"))
                    try await Task.sleep(for: interval)
                    if sharedSearch == nil {
                        continuation.yield(.progress(message: "AI 研讀競品 / 文章 / 開源中…"))
                        try await Task.sleep(for: interval)
                        continuation.yield(.searchResults(PersonaSearchBundle(
                            competitors: [CompetitorItem(source: "web", title: "Moneybook", url: "https://moneybook.com.tw", subtitle: "moneybook.com.tw", summary: "自動同步多銀行的理財管家")],
                            articles: [CompetitorItem(source: "article", title: "2026 記帳 App 推薦", url: "https://example.com/a", subtitle: "example.com", summary: "10 款記帳 App 實測比較")],
                            openSource: [CompetitorItem(source: "github", title: "open/jizhang", url: "https://github.com/open/jizhang", subtitle: "Flutter 記帳", summary: "Flutter 開源記帳 App")],
                            partial: false)))
                    }
                    continuation.yield(.progress(message: "AI 設計定位中…"))
                    for k in 0..<n {
                        let idx = regenerateIndex ?? k
                        let card = cards[regenerateIndex ?? k]
                        continuation.yield(.cardStart(index: idx))
                        for chunk in chunked(card.oneLiner, size: 6) {
                            try await Task.sleep(for: interval)
                            continuation.yield(.delta(index: idx, text: chunk))
                        }
                        continuation.yield(.cardDone(index: idx, card: card))
                    }
                    continuation.yield(.usage(AIUsage(inputTokens: 2400, outputTokens: 2500, cacheReadInputTokens: 1000, model: "stub")))
                    continuation.yield(.done)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 把字串切成等长块（模拟串流 delta）。
    private func chunked(_ s: String, size: Int) -> [String] {
        var out: [String] = []; var cur = ""
        for ch in s { cur.append(ch); if cur.count >= size { out.append(cur); cur = "" } }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    func chatNote(messages: [ChatMessage], note: NotePayload, project: ProjectContext?, mode: String?, kickoff: Bool) -> AsyncThrowingStream<AIEvent, any Error> {
        let deltas = kickoff
            ? ["## 教練開場\n\n", "看了你寫的「\(note.title)」，", "**方向不錯**。先想清楚要解決誰的什麼問題。"]
            : ["## 觀測建議\n\n", "你的表有 **兩個問題**：\n\n", "- 河堤—公園只在週末有紀錄\n", "- 平日 17:00 後常跳過\n\n", "建議改成 `早上通學前` 量。"]
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
                    } else {
                        // 階段三：示範「記入系統結構」——instruction 內為 SpecPatch JSON
                        continuation.yield(.proposal([
                            ProposalItem(action: "update_spec", label: "記入結構",
                                         instruction: #"{"frontend":"SwiftUI","database":"SwiftData","server":"Fly.io"}"#),
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
