import Foundation

// ============================================================
// AI 服務抽象 —— SSE 事件協議照《整合契約 §2》後端裁決，不增不改
// 事件全集：delta/usage/progress/card_start/card_done/card_removed/proposal/done/error
// 實作：Data/AI/AIServiceLive（真後端）、AIServiceStub（開發替身）
// ============================================================

/// usage 事件載荷（扁平，《契約 §2》）。
struct AIUsage: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let model: String
}

/// card_done 的卡片載荷——容納兩種形狀：
/// optimize：`{action:'add',type,content,position}` 或 `{action:'update',id,content}`
/// structure：`{type,title,content,absorbed[]}`
struct CardPayload: Equatable, Sendable {
    let action: String?      // "add" | "update" | nil(structure)
    let id: String?
    let type: String?
    let title: String?
    let content: String?
    let position: Int?
    let absorbed: [String]
}

/// 聊天提議按鈕（proposal 事件）。
struct ProposalItem: Equatable, Sendable {
    let action: String       // edit_text | structure | find_github | find_youtube | find_info
    let label: String        // ≤12 字
    let instruction: String?
}

/// SSE 事件（後端 → App）。形狀對齊《整合契約 §2》。
enum AIEvent: Equatable, Sendable {
    case delta(String)                                           // {text}
    case usage(AIUsage)                                          // 扁平 token 用量
    case progress(current: Int, total: Int, message: String?)   // {current,total,message}
    case cardStart(index: Int, title: String, type: String)     // structure
    case cardDone(index: Int, card: CardPayload)                // optimize/structure
    case cardRemoved(cardId: String)                            // optimize
    case proposal([ProposalItem])                               // chat
    case done                                                   // {}
    case error(code: String, message: String)                  // {code,error}
}

/// 優化確認框（與網頁版一致：單一 groupTopics）。
struct OptimizeOptions: Equatable, Sendable {
    var groupTopics = true
}

/// 傳給 AI 的筆記內容（最小傳輸形）。
struct NotePayload: Equatable, Codable, Sendable {
    struct BlockPayload: Equatable, Codable, Sendable {
        let id: String
        let type: String
        let content: String
        let pinned: Bool
        var changed: Bool?     // optimize/applyEdit 標記可整理對象
        var module: Bool?      // structure 標註模組塊
    }

    let title: String
    let blocks: [BlockPayload]
}

extension NotePayload {
    /// 從領域模型組裝（釘選塊標記 pinned，後端不得改動）。
    init(note: Note) {
        self.title = note.title
        self.blocks = note.blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { block in
                BlockPayload(
                    id: block.id.uuidString,
                    type: block.kind.rawValue,
                    content: block.text,
                    pinned: block.isPinned,
                    changed: nil,
                    module: block.kind == .module
                )
            }
    }
}

/// 聊天訊息（role 對齊後端：user | ai）。
struct ChatMessage: Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case ai
    }

    let role: Role
    let content: String
}

/// AI 服務協議 —— UI 永遠只認識這個介面。路徑/簽名對齊《整合契約 §1/§5》。
protocol AIServicing: Sendable {
    /// 健康檢查（啟動自檢用）。
    func health() async -> Bool

    /// 跟筆記對話（kickoff=true 時 messages 可空，教練主動開口）。
    func chatNote(messages: [ChatMessage], note: NotePayload, kickoff: Bool) -> AsyncThrowingStream<AIEvent, any Error>

    /// ✦ 優化文字。
    func optimize(note: NotePayload, groupTopics: Bool, instruction: String?) -> AsyncThrowingStream<AIEvent, any Error>

    /// ▦ 卡片結構化（mode=full）。
    func structure(note: NotePayload) -> AsyncThrowingStream<AIEvent, any Error>
}
