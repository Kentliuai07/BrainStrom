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

/// 內容塊類型。（釘選統一用 Block.isPinned，不再有獨立 pinned 型別）
enum BlockKind: String, Codable, Sendable {
    case paragraph
    case heading1
    case heading2
    case todo
    case module     // 內嵌模組卡（恆釘選）
}

/// 塊來源（《整合契約 §4》）。
enum BlockSource: String, Codable, Sendable {
    case manual
    case ai
    case notes
}

/// 點子助攻狀態機（《整合契約 §4》Nudge）。
struct Nudge: Codable, Hashable, Sendable {
    enum State: String, Codable, Sendable {
        case pending
        case dismissed
        case opened
    }
    var state: State
    var hash: String?
    var openingText: String?
    var openingProposals: [ProposalSnapshot]
    var at: Date?

    init(state: State = .pending, hash: String? = nil,
         openingText: String? = nil, openingProposals: [ProposalSnapshot] = [], at: Date? = nil) {
        self.state = state
        self.hash = hash
        self.openingText = openingText
        self.openingProposals = openingProposals
        self.at = at
    }
}

/// 教練開場的提議快照（可重播；對齊 SSE proposal）。
struct ProposalSnapshot: Codable, Hashable, Sendable {
    let action: String
    let label: String
    let instruction: String?
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
    var ownerId: String?
    var tags: [String]

    init(id: UUID = UUID(), name: String,
         createdAt: Date = .now, updatedAt: Date = .now,
         noteCount: Int = 0, cardCount: Int = 0,
         visibility: Visibility = .private, snippet: String = "",
         ownerId: String? = nil, tags: [String] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.noteCount = noteCount
        self.cardCount = cardCount
        self.visibility = visibility
        self.snippet = snippet
        self.ownerId = ownerId
        self.tags = tags
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
    var lastAiHash: String?         // 整篇指紋（hash gate 省錢閘）
    var aiRestructureCount: Int     // 結構化次數
    var structuredAt: Date?         // 最後結構化時間
    var nudge: Nudge                // 點子助攻狀態

    /// 存活（未軟刪）的塊，依序。
    var liveBlocks: [Block] {
        blocks.filter { !$0.isDeleted }.sorted { $0.orderIndex < $1.orderIndex }
    }

    var characterCount: Int {
        liveBlocks.reduce(0) { $0 + $1.text.count }
    }

    init(id: UUID = UUID(), systemID: UUID, title: String,
         docState: DocState = .raw, blocks: [Block] = [],
         updatedAt: Date = .now, revisionNumber: Int = 1,
         lastAiHash: String? = nil, aiRestructureCount: Int = 0,
         structuredAt: Date? = nil, nudge: Nudge = Nudge()) {
        self.id = id
        self.systemID = systemID
        self.title = title
        self.docState = docState
        self.blocks = blocks
        self.updatedAt = updatedAt
        self.revisionNumber = revisionNumber
        self.lastAiHash = lastAiHash
        self.aiRestructureCount = aiRestructureCount
        self.structuredAt = structuredAt
        self.nudge = nudge
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
    var source: BlockSource     // 來源：手動/AI/匯入
    var aiHash: String?         // 該塊內容指紋（diff 省錢閘用）
    var structureGen: Int       // 結構化世代
    var deletedAt: Date?        // 軟刪時間戳（nil=存活）
    var cardTitle: String?      // 結構化卡標（web payload={title,content} 的 title）

    var isDeleted: Bool { deletedAt != nil }

    init(id: UUID = UUID(), kind: BlockKind, text: String = "",
         isDone: Bool = false, isPinned: Bool = false, moduleKind: ModuleKind? = nil,
         modulePayload: String? = nil, orderIndex: Int = 0,
         source: BlockSource = .manual, aiHash: String? = nil,
         structureGen: Int = 0, deletedAt: Date? = nil, cardTitle: String? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.isDone = isDone
        self.isPinned = isPinned
        self.moduleKind = moduleKind
        self.modulePayload = modulePayload
        self.orderIndex = orderIndex
        self.source = source
        self.aiHash = aiHash
        self.structureGen = structureGen
        self.deletedAt = deletedAt
        self.cardTitle = cardTitle
    }

    // 向後相容解碼：舊資料缺新鍵時給預設值。
    enum CodingKeys: String, CodingKey {
        case id, kind, text, isDone, isPinned, moduleKind, modulePayload, orderIndex
        case source, aiHash, structureGen, deletedAt, cardTitle
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
        source = try c.decodeIfPresent(BlockSource.self, forKey: .source) ?? .manual
        aiHash = try c.decodeIfPresent(String.self, forKey: .aiHash)
        structureGen = try c.decodeIfPresent(Int.self, forKey: .structureGen) ?? 0
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        cardTitle = try c.decodeIfPresent(String.self, forKey: .cardTitle)
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
