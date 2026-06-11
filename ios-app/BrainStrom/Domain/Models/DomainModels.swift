import Foundation

// ============================================================
// 領域模型 —— 活文件模型 v3：塊串、文章/卡片同一資料
// 純值型別、全 Sendable；持久化映射在 Data/Persistence
// ============================================================

/// 文件狀態機：raw → optimized → carded。
enum DocState: String, Codable, Sendable {
    case raw
    case optimized
    case carded
}

/// 內容塊類型。
enum BlockKind: String, Codable, Sendable {
    case paragraph
    case heading1
    case heading2
    case todo
    case pinned     // AI 永不改動
    case module     // 內嵌模組卡
}

/// 模組類型（PRO 鎖另由授權層判定，不做付費牆）。
enum ModuleKind: String, Codable, Sendable {
    case table
    case progress
    case github
}

/// 版本類型（版本歷史 LED 色語義）。
enum RevisionKind: String, Codable, Sendable {
    case optimize   // 橘
    case structize  // 綠
    case manual     // 灰
    case restore    // 紅
}

/// 可見性（首頁卡片與筆記頁的私密/公開膠囊）。
enum Visibility: String, Codable, Sendable {
    case `private`
    case `public`
}

/// 系統（＝一份活文件；首頁機架上的一塊模組）。
/// 對齊 web 模型：一個 system 就是一份可開的文件，沒有「系統內筆記列表」中間層。
struct NoteSystem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var noteCount: Int
    var cardCount: Int
    var visibility: Visibility
    var snippet: String

    init(id: UUID = UUID(), name: String,
         createdAt: Date = .now, updatedAt: Date = .now,
         noteCount: Int = 0, cardCount: Int = 0,
         visibility: Visibility = .private, snippet: String = "") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.noteCount = noteCount
        self.cardCount = cardCount
        self.visibility = visibility
        self.snippet = snippet
    }
}

/// 筆記（活文件）。
struct Note: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var systemID: UUID
    var title: String
    var docState: DocState
    var blocks: [Block]
    var updatedAt: Date
    var revisionNumber: Int

    var characterCount: Int {
        blocks.reduce(0) { $0 + $1.text.count }
    }

    init(id: UUID = UUID(), systemID: UUID, title: String,
         docState: DocState = .raw, blocks: [Block] = [],
         updatedAt: Date = .now, revisionNumber: Int = 1) {
        self.id = id
        self.systemID = systemID
        self.title = title
        self.docState = docState
        self.blocks = blocks
        self.updatedAt = updatedAt
        self.revisionNumber = revisionNumber
    }
}

/// 內容塊。
struct Block: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var kind: BlockKind
    var text: String
    var isDone: Bool            // todo 專用
    var isPinned: Bool          // text/heading 可釘選（AI 永不動）；module 恆釘選
    var moduleKind: ModuleKind? // module 專用
    var modulePayload: String?  // module 結構化資料（JSON）
    var orderIndex: Int

    init(id: UUID = UUID(), kind: BlockKind, text: String = "",
         isDone: Bool = false, isPinned: Bool = false, moduleKind: ModuleKind? = nil,
         modulePayload: String? = nil, orderIndex: Int = 0) {
        self.id = id
        self.kind = kind
        self.text = text
        self.isDone = isDone
        self.isPinned = isPinned
        self.moduleKind = moduleKind
        self.modulePayload = modulePayload
        self.orderIndex = orderIndex
    }

    // 向後相容解碼：舊資料沒有 isPinned 鍵時預設 false。
    enum CodingKeys: String, CodingKey {
        case id, kind, text, isDone, isPinned, moduleKind, modulePayload, orderIndex
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(BlockKind.self, forKey: .kind)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        moduleKind = try c.decodeIfPresent(ModuleKind.self, forKey: .moduleKind)
        modulePayload = try c.decodeIfPresent(String.self, forKey: .modulePayload)
        orderIndex = try c.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
    }
}

/// 卡片（卡片視圖的板卡；與文章同源）。
struct Card: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var noteID: UUID
    var title: String
    var body: String
    var isPinned: Bool
    var moduleKind: ModuleKind?
    var modulePayload: String?
    var orderIndex: Int

    init(id: UUID = UUID(), noteID: UUID, title: String, body: String = "",
         isPinned: Bool = false, moduleKind: ModuleKind? = nil,
         modulePayload: String? = nil, orderIndex: Int = 0) {
        self.id = id
        self.noteID = noteID
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.moduleKind = moduleKind
        self.modulePayload = modulePayload
        self.orderIndex = orderIndex
    }
}

/// 版本（磁帶記錄器的一格）。
struct Revision: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var noteID: UUID
    var kind: RevisionKind
    var createdAt: Date
    var charDelta: Int
    var cardCount: Int?

    init(id: UUID = UUID(), noteID: UUID, kind: RevisionKind,
         createdAt: Date = .now, charDelta: Int = 0, cardCount: Int? = nil) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.createdAt = createdAt
        self.charDelta = charDelta
        self.cardCount = cardCount
    }
}
