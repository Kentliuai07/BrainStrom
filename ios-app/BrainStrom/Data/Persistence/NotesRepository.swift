import Foundation
import SwiftData

// ============================================================
// 筆記倉儲 · SwiftData 實作 —— 永不丟字的落盤層
// ============================================================

@MainActor
final class NotesRepository: NotesRepositoring {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 系統

    func systems() throws -> [NoteSystem] {
        let descriptor = FetchDescriptor<SystemEntity>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor).map { entity in
            NoteSystem(
                id: entity.id,
                name: entity.name,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt,
                noteCount: entity.notes.count,
                cardCount: entity.notes.reduce(0) { $0 + $1.cards.count },
                visibility: entity.visibilityRaw.flatMap(Visibility.init(rawValue:)) ?? .private,
                snippet: snippet(of: entity),
                ownerId: entity.ownerId,
                tags: entity.tagsData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
            )
        }
    }

    func setVisibility(systemID: UUID, to visibility: Visibility) throws {
        guard let entity = try fetchSystem(id: systemID) else { return }
        entity.visibilityRaw = visibility.rawValue
        try context.save()
    }

    /// 對齊 web 模型：一個 system = 一份文件。取出（或惰性建立）該 system 的唯一筆記。
    @discardableResult
    func documentNote(for systemID: UUID) throws -> Note {
        guard let system = try fetchSystem(id: systemID) else {
            throw RepositoryError.systemNotFound
        }
        if let first = system.notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            return try toDomain(first)
        }
        return try createNote(in: systemID, title: system.name)
    }

    /// 改系統名稱（＝文件標題；首頁卡片標題同源）。
    func renameSystem(id: UUID, name: String) throws {
        guard let entity = try fetchSystem(id: id) else { return }
        entity.name = name
        entity.updatedAt = .now
        try context.save()
    }

    /// 首頁摘要：取該 system 唯一筆記的第一個文字/標題塊（去頭尾空白、截 60 字）。
    private func snippet(of entity: SystemEntity) -> String {
        guard let note = entity.notes.sorted(by: { $0.updatedAt > $1.updatedAt }).first,
              let blocks = try? JSONDecoder().decode([Block].self, from: note.blocksData) else { return "" }
        let firstText = blocks
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { ($0.kind == .paragraph || $0.kind == .heading1 || $0.kind == .heading2)
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let raw = (firstText?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.count > 60 ? String(raw.prefix(60)) + "…" : raw
    }

    @discardableResult
    func createSystem(name: String) throws -> NoteSystem {
        let entity = SystemEntity(id: UUID(), name: name, createdAt: .now, updatedAt: .now)
        context.insert(entity)
        try context.save()
        return NoteSystem(id: entity.id, name: entity.name,
                          createdAt: entity.createdAt, updatedAt: entity.updatedAt)
    }

    func deleteSystem(id: UUID) throws {
        guard let entity = try fetchSystem(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - 筆記

    func notes(in systemID: UUID) throws -> [Note] {
        guard let system = try fetchSystem(id: systemID) else { return [] }
        return try system.notes
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(toDomain(_:))
    }

    func note(id: UUID) throws -> Note? {
        guard let entity = try fetchNote(id: id) else { return nil }
        return try toDomain(entity)
    }

    @discardableResult
    func createNote(in systemID: UUID, title: String) throws -> Note {
        guard let system = try fetchSystem(id: systemID) else {
            throw RepositoryError.systemNotFound
        }
        let note = Note(systemID: systemID, title: title)
        let entity = NoteEntity(
            id: note.id,
            title: note.title,
            docStateRaw: note.docState.rawValue,
            blocksData: try JSONEncoder().encode(note.blocks),
            updatedAt: note.updatedAt,
            revisionNumber: note.revisionNumber
        )
        entity.system = system
        context.insert(entity)
        system.updatedAt = .now
        try context.save()
        return note
    }

    func saveNote(_ note: Note) throws {
        guard let entity = try fetchNote(id: note.id) else {
            throw RepositoryError.noteNotFound
        }
        entity.title = note.title
        entity.docStateRaw = note.docState.rawValue
        entity.blocksData = try JSONEncoder().encode(note.blocks)
        entity.updatedAt = .now
        entity.revisionNumber = note.revisionNumber
        entity.lastAiHash = note.lastAiHash
        entity.aiRestructureCount = note.aiRestructureCount
        entity.structuredAt = note.structuredAt
        entity.nudgeData = try? JSONEncoder().encode(note.nudge)
        entity.system?.updatedAt = .now
        try context.save()
    }

    func deleteNote(id: UUID) throws {
        guard let entity = try fetchNote(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - 卡片

    func cards(of noteID: UUID) throws -> [Card] {
        guard let note = try fetchNote(id: noteID) else { return [] }
        return note.cards
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { entity in
                Card(
                    id: entity.id,
                    noteID: noteID,
                    title: entity.title,
                    body: entity.body,
                    isPinned: entity.isPinned,
                    moduleKind: entity.moduleKindRaw.flatMap(ModuleKind.init(rawValue:)),
                    modulePayload: entity.modulePayload,
                    orderIndex: entity.orderIndex
                )
            }
    }

    func saveCards(_ cards: [Card], noteID: UUID) throws {
        guard let note = try fetchNote(id: noteID) else {
            throw RepositoryError.noteNotFound
        }
        for old in note.cards {
            context.delete(old)
        }
        for card in cards {
            let entity = CardEntity(
                id: card.id,
                title: card.title,
                body: card.body,
                isPinned: card.isPinned,
                moduleKindRaw: card.moduleKind?.rawValue,
                modulePayload: card.modulePayload,
                orderIndex: card.orderIndex
            )
            entity.note = note
            context.insert(entity)
        }
        note.updatedAt = .now
        try context.save()
    }

    // MARK: - 版本

    func snapshot(noteID: UUID, kind: RevisionKind, charDelta: Int, cardCount: Int?) throws {
        guard let note = try fetchNote(id: noteID) else {
            throw RepositoryError.noteNotFound
        }
        let entity = RevisionEntity(
            id: UUID(),
            kindRaw: kind.rawValue,
            createdAt: .now,
            charDelta: charDelta,
            cardCount: cardCount
        )
        entity.note = note
        context.insert(entity)
        note.revisionNumber += 1
        try context.save()
    }

    func revisions(of noteID: UUID) throws -> [Revision] {
        guard let note = try fetchNote(id: noteID) else { return [] }
        return note.revisions
            .sorted { $0.createdAt > $1.createdAt }
            .map { entity in
                Revision(
                    id: entity.id,
                    noteID: noteID,
                    kind: RevisionKind(rawValue: entity.kindRaw) ?? .manual,
                    createdAt: entity.createdAt,
                    charDelta: entity.charDelta,
                    cardCount: entity.cardCount
                )
            }
    }

    // MARK: - 版本指針法（《整合契約 §4》）

    /// 是否已有任何版本（NoteDocument 載入時決定要不要種 v0）。
    func hasVersions(noteID: UUID) throws -> Bool {
        guard let note = try fetchNote(id: noteID) else { return false }
        return !note.revisions.isEmpty
    }

    /// 提交一個版本（commit-after-change）：清 redo → 去重 → append → 指針=末位。
    func commitVersion(noteID: UUID, snapshot: Data, trigger: String) throws {
        guard let note = try fetchNote(id: noteID) else { return }
        let snapStr = String(decoding: snapshot, as: UTF8.self)
        let ptr = note.versionPointer
        // 清掉指針之後的版本（砍 redo 分支）
        for rev in note.revisions where rev.versionNumber > ptr {
            context.delete(rev)
        }
        // 與目前指針版本內容相同 → 去重不落步
        if let current = note.revisions.first(where: { $0.versionNumber == ptr }),
           current.blocksJson == snapStr {
            return
        }
        let newNumber = ptr + 1
        let rev = RevisionEntity(id: UUID(), kindRaw: trigger, createdAt: .now,
                                 charDelta: 0, cardCount: nil,
                                 versionNumber: newNumber, blocksJson: snapStr)
        rev.note = note
        context.insert(rev)
        note.versionPointer = newNumber
        try context.save()
    }

    /// 撤銷：指針 -1，回傳該版本快照（越界回 nil）。
    func undoVersion(noteID: UUID) throws -> Data? {
        guard let note = try fetchNote(id: noteID), note.versionPointer > 0 else { return nil }
        let target = note.versionPointer - 1
        note.versionPointer = target
        try context.save()
        return snapshotData(of: note, versionNumber: target)
    }

    /// 重做：指針 +1，回傳該版本快照（越界回 nil）。
    func redoVersion(noteID: UUID) throws -> Data? {
        guard let note = try fetchNote(id: noteID) else { return nil }
        let maxNumber = note.revisions.map(\.versionNumber).max() ?? -1
        guard note.versionPointer < maxNumber else { return nil }
        let target = note.versionPointer + 1
        note.versionPointer = target
        try context.save()
        return snapshotData(of: note, versionNumber: target)
    }

    /// ↶↷ 可用狀態。
    func versionState(noteID: UUID) throws -> (canUndo: Bool, canRedo: Bool) {
        guard let note = try fetchNote(id: noteID) else { return (false, false) }
        let maxNumber = note.revisions.map(\.versionNumber).max() ?? -1
        return (note.versionPointer > 0, note.versionPointer < maxNumber)
    }

    private func snapshotData(of note: NoteEntity, versionNumber: Int) -> Data? {
        note.revisions.first { $0.versionNumber == versionNumber }?
            .blocksJson.flatMap { Data($0.utf8) }
    }

    // MARK: - 私有

    private func fetchSystem(id: UUID) throws -> SystemEntity? {
        var descriptor = FetchDescriptor<SystemEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchNote(id: UUID) throws -> NoteEntity? {
        var descriptor = FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func toDomain(_ entity: NoteEntity) throws -> Note {
        Note(
            id: entity.id,
            systemID: entity.system?.id ?? UUID(),
            title: entity.title,
            docState: DocState(rawValue: entity.docStateRaw) ?? .raw,
            blocks: (try? JSONDecoder().decode([Block].self, from: entity.blocksData)) ?? [],
            updatedAt: entity.updatedAt,
            revisionNumber: entity.revisionNumber,
            lastAiHash: entity.lastAiHash,
            aiRestructureCount: entity.aiRestructureCount,
            structuredAt: entity.structuredAt,
            nudge: entity.nudgeData.flatMap { try? JSONDecoder().decode(Nudge.self, from: $0) } ?? Nudge()
        )
    }
}

/// 倉儲錯誤。
enum RepositoryError: Error {
    case systemNotFound
    case noteNotFound
}
