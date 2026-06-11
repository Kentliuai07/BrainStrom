import Foundation

// ============================================================
// AI 服務抽象 —— SSE 事件協議照阶段二文档 §2.1，不增不改
// 實作：Data/AI/AIServiceLive（真後端）、AIServiceStub（開發替身）
// ============================================================

/// SSE 事件（後端 → App）。
enum AIEvent: Equatable, Sendable {
    case delta(String)                          // 流式文字片段
    case done                                   // 本次任務完成
    case error(message: String)                 // 錯誤（人話訊息）
    case usage(inputTokens: Int, outputTokens: Int)
    case cardStart(id: String, title: String)   // 開始產出一張卡
    case cardDone(id: String)                   // 卡片完成
    case cardRemoved(id: String)                // 卡片被合併移除
    case progress(Double)                       // 0…1
    case hitList([SearchHit])                   // 搜索命中清單
}

/// 全局搜索命中。
struct SearchHit: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let systemName: String
}

/// 優化選項（AI 確認銘板上的三顆開關）。
struct OptimizeOptions: Equatable, Sendable {
    var splitTopics = true
    var addHeadings = true
    var proofread = false
}

/// 傳給 AI 的筆記內容（最小傳輸形）。
struct NotePayload: Equatable, Codable, Sendable {
    struct BlockPayload: Equatable, Codable, Sendable {
        let id: String
        let kind: String
        let text: String
        let pinned: Bool
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
                    kind: block.kind.rawValue,
                    text: block.text,
                    pinned: block.kind == .pinned
                )
            }
    }
}

/// 聊天訊息。
struct ChatMessage: Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let text: String
}

/// AI 服務協議 —— UI 永遠只認識這個介面。
protocol AIServicing: Sendable {
    /// 健康檢查（啟動自檢用）。
    func health() async -> Bool

    /// ✦ 優化文字。
    func optimize(_ payload: NotePayload, options: OptimizeOptions) -> AsyncThrowingStream<AIEvent, any Error>

    /// ▦ 卡片結構化。
    func structure(_ payload: NotePayload) -> AsyncThrowingStream<AIEvent, any Error>

    /// 跟筆記對話。
    func chat(messages: [ChatMessage], context: NotePayload?) -> AsyncThrowingStream<AIEvent, any Error>

    /// 全局 AI 搜索。
    func search(query: String) -> AsyncThrowingStream<AIEvent, any Error>
}
