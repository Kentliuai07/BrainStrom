import XCTest
import SwiftData
@testable import BrainStrom

// ============================================================
// 版本指針法測試（《整合契約 §4》）—— 記憶體 SwiftData
// 驗收：A→B→undo→undo→redo→redo 正確、去重、砍 redo 分支
// ============================================================

@MainActor
final class VersionTests: XCTestCase {

    private func makeRepo() throws -> (NotesRepository, UUID) {
        let container = try ModelContainer(
            for: SystemEntity.self, NoteEntity.self, CardEntity.self, RevisionEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repo = NotesRepository(context: ModelContext(container))
        let sys = try repo.createSystem(name: "T")
        let note = try repo.documentNote(for: sys.id)
        return (repo, note.id)
    }

    private func snap(_ s: String) -> Data { Data(s.utf8) }

    func testPointerLawUndoRedo() throws {
        let (repo, id) = try makeRepo()
        try repo.commitVersion(noteID: id, snapshot: snap("v0"), trigger: "open")
        try repo.commitVersion(noteID: id, snapshot: snap("A"), trigger: "cardEdit")
        try repo.commitVersion(noteID: id, snapshot: snap("AB"), trigger: "cardEdit")

        var st = try repo.versionState(noteID: id)
        XCTAssertTrue(st.canUndo); XCTAssertFalse(st.canRedo)

        XCTAssertEqual(try repo.undoVersion(noteID: id), snap("A"))
        XCTAssertEqual(try repo.undoVersion(noteID: id), snap("v0"))
        XCTAssertNil(try repo.undoVersion(noteID: id))          // 越界

        st = try repo.versionState(noteID: id)
        XCTAssertFalse(st.canUndo); XCTAssertTrue(st.canRedo)

        XCTAssertEqual(try repo.redoVersion(noteID: id), snap("A"))
        XCTAssertEqual(try repo.redoVersion(noteID: id), snap("AB"))
        XCTAssertNil(try repo.redoVersion(noteID: id))          // 越界
    }

    func testDedupSameContent() throws {
        let (repo, id) = try makeRepo()
        try repo.commitVersion(noteID: id, snapshot: snap("X"), trigger: "open")
        try repo.commitVersion(noteID: id, snapshot: snap("X"), trigger: "cardEdit")  // 同內容→去重
        XCTAssertFalse(try repo.versionState(noteID: id).canUndo)                      // 只有 1 版
    }

    func testNewCommitTruncatesRedo() throws {
        let (repo, id) = try makeRepo()
        try repo.commitVersion(noteID: id, snapshot: snap("v0"), trigger: "open")
        try repo.commitVersion(noteID: id, snapshot: snap("A"), trigger: "cardEdit")
        _ = try repo.undoVersion(noteID: id)                     // 回 v0，redo 可用
        XCTAssertTrue(try repo.versionState(noteID: id).canRedo)
        try repo.commitVersion(noteID: id, snapshot: snap("B"), trigger: "cardEdit")  // 新分支→砍掉 redo(A)
        XCTAssertFalse(try repo.versionState(noteID: id).canRedo)
        XCTAssertEqual(try repo.undoVersion(noteID: id), snap("v0"))
    }
}
