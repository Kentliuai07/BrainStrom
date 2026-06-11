import Foundation

// ============================================================
// 筆記倉儲抽象 —— 永不丟字：即時持久化＋AI 前自動快照
// 實作：Data/Persistence/NotesRepository（SwiftData）
// ============================================================

/// 筆記倉儲協議（UI 執行緒存取，SwiftData ModelContext 綁定主執行緒）。
@MainActor
protocol NotesRepositoring: AnyObject {

    // —— 系統（＝活文件，對齊 web 模型）——
    func systems() throws -> [NoteSystem]
    @discardableResult
    func createSystem(name: String) throws -> NoteSystem
    func deleteSystem(id: UUID) throws
    func setVisibility(systemID: UUID, to visibility: Visibility) throws
    func renameSystem(id: UUID, name: String) throws
    /// 取出（或惰性建立）某 system 的唯一文件筆記。
    @discardableResult
    func documentNote(for systemID: UUID) throws -> Note

    // —— 筆記 ——
    func notes(in systemID: UUID) throws -> [Note]
    func note(id: UUID) throws -> Note?
    @discardableResult
    func createNote(in systemID: UUID, title: String) throws -> Note
    /// 即時持久化（每次編輯落盤）。
    func saveNote(_ note: Note) throws
    func deleteNote(id: UUID) throws

    // —— 卡片 ——
    func cards(of noteID: UUID) throws -> [Card]
    func saveCards(_ cards: [Card], noteID: UUID) throws

    // —— 版本（磁帶）——
    /// AI 操作前必呼叫：自動快照。
    func snapshot(noteID: UUID, kind: RevisionKind, charDelta: Int, cardCount: Int?) throws
    func revisions(of noteID: UUID) throws -> [Revision]
}
