import Foundation
import SwiftData

// ============================================================
// SwiftData 實體 —— 領域模型的持久化映射
// 註：blocks 以 JSON Data 內嵌（活文件是整份讀寫的文件型資料）
// ============================================================

@Model
final class SystemEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    /// 可見性（nil 視為 private；optional 以支援既有 DB 輕量遷移）。
    var visibilityRaw: String?
    /// 擁有者（鑑權；nil=舊資料）。
    var ownerId: String?
    /// 標籤（JSON 編碼的 [String]）。
    var tagsData: Data?

    @Relationship(deleteRule: .cascade, inverse: \NoteEntity.system)
    var notes: [NoteEntity] = []

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date,
         visibilityRaw: String? = Visibility.private.rawValue,
         ownerId: String? = nil, tagsData: Data? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visibilityRaw = visibilityRaw
        self.ownerId = ownerId
        self.tagsData = tagsData
    }
}

@Model
final class NoteEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var docStateRaw: String
    var blocksData: Data
    var updatedAt: Date
    var revisionNumber: Int
    /// 整篇指紋（hash gate 省錢閘）。
    var lastAiHash: String?
    /// 結構化次數。
    var aiRestructureCount: Int = 0
    /// 最後結構化時間。
    var structuredAt: Date?
    /// 點子助攻狀態（JSON 編碼的 Nudge）。
    var nudgeData: Data?

    var system: SystemEntity?

    @Relationship(deleteRule: .cascade, inverse: \CardEntity.note)
    var cards: [CardEntity] = []

    @Relationship(deleteRule: .cascade, inverse: \RevisionEntity.note)
    var revisions: [RevisionEntity] = []

    init(id: UUID, title: String, docStateRaw: String, blocksData: Data,
         updatedAt: Date, revisionNumber: Int,
         lastAiHash: String? = nil, aiRestructureCount: Int = 0,
         structuredAt: Date? = nil, nudgeData: Data? = nil) {
        self.id = id
        self.title = title
        self.docStateRaw = docStateRaw
        self.blocksData = blocksData
        self.updatedAt = updatedAt
        self.revisionNumber = revisionNumber
        self.lastAiHash = lastAiHash
        self.aiRestructureCount = aiRestructureCount
        self.structuredAt = structuredAt
        self.nudgeData = nudgeData
    }
}

@Model
final class CardEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var isPinned: Bool
    var moduleKindRaw: String?
    var modulePayload: String?
    var orderIndex: Int

    var note: NoteEntity?

    init(id: UUID, title: String, body: String, isPinned: Bool,
         moduleKindRaw: String?, modulePayload: String?, orderIndex: Int) {
        self.id = id
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.moduleKindRaw = moduleKindRaw
        self.modulePayload = modulePayload
        self.orderIndex = orderIndex
    }
}

@Model
final class RevisionEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var createdAt: Date
    var charDelta: Int
    var cardCount: Int?

    var note: NoteEntity?

    init(id: UUID, kindRaw: String, createdAt: Date, charDelta: Int, cardCount: Int?) {
        self.id = id
        self.kindRaw = kindRaw
        self.createdAt = createdAt
        self.charDelta = charDelta
        self.cardCount = cardCount
    }
}

/// 全 App 的 Schema（ModelContainer 用）。
enum PersistenceSchema {
    static let models: [any PersistentModel.Type] = [
        SystemEntity.self, NoteEntity.self, CardEntity.self, RevisionEntity.self,
    ]
}
