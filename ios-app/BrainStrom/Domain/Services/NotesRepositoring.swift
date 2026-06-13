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
    // —— 系統身份證（階段三）——
    func systemSpec(systemID: UUID) throws -> SystemSpec?
    func updateSystemSpec(systemID: UUID, spec: SystemSpec) throws

    // —— 主筆記錨點（階段三 v3）——
    /// 建系統並同時種下主筆記（原子）：回 (系統, 主筆記)。initialContent 非空＝寫成主筆記第一塊（AI 引導/手動可讀）。
    @discardableResult
    func createSystemWithPrimaryNote(name: String, initialContent: String?) throws -> (system: NoteSystem, note: Note)
    /// 取該系統的主筆記 ID（nil=舊資料未設）。
    func primaryNoteID(for systemID: UUID) throws -> UUID?
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
    func revisions(of noteID: UUID) throws -> [Revision]

    // —— 版本指針法（undo/redo，《整合契約 §4》）——
    func hasVersions(noteID: UUID) throws -> Bool
    func commitVersion(noteID: UUID, snapshot: Data, trigger: String) throws
    func undoVersion(noteID: UUID) throws -> Data?
    func redoVersion(noteID: UUID) throws -> Data?
    func versionState(noteID: UUID) throws -> (canUndo: Bool, canRedo: Bool)
}
