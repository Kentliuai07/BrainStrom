import Foundation

// ============================================================
// 筆記頁本地文件 store —— 驅動活文件編輯器
// 對齊 web main.js 的 note() 行為；本地 SwiftData 落盤、記憶體 undo/redo。
// AI（✦ 優化／▦ 結構化／💬 聊天）先不接後端（照 web：非 real 時提示）。
// ============================================================

@MainActor
@Observable
final class NoteDocument {

    enum ViewMode { case article, cards }

    let systemID: UUID
    private let repository: any NotesRepositoring

    private(set) var noteID: UUID
    var title: String
    private(set) var blocks: [Block]
    private(set) var docState: DocState
    private(set) var visibility: Visibility

    var view: ViewMode = .article
    private(set) var naming: Bool = false
    var savedFlash = false

    // 記憶體 undo/redo（web 用 server 版本；此處本地）。
    private var undoStack: [(String, [Block])] = []
    private var redoStack: [(String, [Block])] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init?(systemID: UUID, repository: any NotesRepositoring) {
        self.systemID = systemID
        self.repository = repository
        guard let note = try? repository.documentNote(for: systemID) else { return nil }
        self.noteID = note.id
        self.title = note.title
        self.blocks = note.blocks.sorted { $0.orderIndex < $1.orderIndex }
        self.docState = note.docState
        let system = (try? repository.systems())?.first { $0.id == systemID }
        self.visibility = system?.visibility ?? .private
        self.naming = Self.isNamingGate(title: note.title, blocks: self.blocks)
        if view == .cards && docState != .carded { view = .article }
    }

    /// 排序後的塊（已維持 orderIndex）。
    var orderedBlocks: [Block] { blocks }

    var docStateIsCarded: Bool { docState == .carded }

    // MARK: - 命名態（F9 gate）

    static func isNamingGate(title: String, blocks: [Block]) -> Bool {
        let zero = blocks.isEmpty
        let t = title.trimmingCharacters(in: .whitespaces)
        return zero && (t.isEmpty || title == "未命名系統" || title == "未命名系统")
    }

    // MARK: - 標題

    func commitTitle(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let zero = blocks.isEmpty
        if v.isEmpty {
            if !zero {
                if title != "未命名系統" { title = "未命名系統"; persist() }
            } else {
                title = ""
                if !naming { naming = true }
                persist()
            }
            return
        }
        if v != title { title = v; persist() }
        if naming { naming = false }
    }

    /// 命名態快速命名（web「先隨便取」）。
    func quickName() -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        let name = f.string(from: .now) + " " + String(localized: "隨手記")
        commitTitle(name)
        return name
    }

    // MARK: - 塊編輯

    func editBlockText(_ id: UUID, to text: String) {
        guard let i = blocks.firstIndex(where: { $0.id == id }), blocks[i].text != text else { return }
        pushUndo()
        blocks[i].text = text
        persist()
    }

    func toggleTodo(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        blocks[i].isDone.toggle()
        persist()
    }

    func togglePin(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[i].isPinned.toggle()
        persist()
    }

    func move(_ id: UUID, by step: Int) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        let ni = i + step
        guard ni >= 0 && ni < blocks.count else { return }
        pushUndo()
        blocks.swapAt(i, ni)
        reindex()
        persist()
    }

    func delete(_ id: UUID) {
        guard blocks.contains(where: { $0.id == id }) else { return }
        pushUndo()
        blocks.removeAll { $0.id == id }
        reindex()
        persist()
    }

    /// 文末「繼續寫…」提交：空行分段、`#` 開頭成標題。
    func appendFromContinue(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        pushUndo()
        for seg in Self.splitIntoBlocks(text) {
            var b = seg
            b.orderIndex = blocks.count
            blocks.append(b)
        }
        persist()
    }

    /// 加模組（web dial）：text/todo/heading 可插；module 類恆釘選。
    func insertModule(_ moduleID: String) {
        pushUndo()
        let kind: BlockKind
        var module: ModuleKind?
        switch moduleID {
        case "todo": kind = .todo
        case "heading": kind = .heading1
        case "text": kind = .paragraph
        default: kind = .module; module = ModuleKind(rawValue: moduleID)
        }
        let block = Block(kind: kind, text: "",
                          isPinned: kind == .module,
                          moduleKind: module, orderIndex: blocks.count)
        blocks.append(block)
        persist()
    }

    func toggleVisibility() {
        visibility = visibility == .private ? .public : .private
        try? repository.setVisibility(systemID: systemID, to: visibility)
    }

    func setView(_ v: ViewMode) {
        if v == .cards && docState != .carded { return }
        view = v
    }

    // MARK: - Undo / Redo（本地）

    func undo() -> Bool {
        guard let snap = undoStack.popLast() else { return false }
        redoStack.append((title, blocks))
        (title, blocks) = snap
        persist(track: false)
        return true
    }

    func redo() -> Bool {
        guard let snap = redoStack.popLast() else { return false }
        undoStack.append((title, blocks))
        (title, blocks) = snap
        persist(track: false)
        return true
    }

    private func pushUndo() {
        undoStack.append((title, blocks))
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: - 持久化

    private func reindex() {
        for i in blocks.indices { blocks[i].orderIndex = i }
    }

    private func persist(track: Bool = true) {
        reindex()
        naming = Self.isNamingGate(title: title, blocks: blocks)
        let note = Note(id: noteID, systemID: systemID, title: title,
                        docState: docState, blocks: blocks, updatedAt: .now)
        try? repository.saveNote(note)
        try? repository.renameSystem(id: systemID, name: title)
        flashSaved()
    }

    private func flashSaved() {
        savedFlash = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            savedFlash = false
        }
    }

    // MARK: - 切塊

    static func splitIntoBlocks(_ text: String) -> [Block] {
        let paragraphs = text.components(separatedBy: "\n\n")
        var result: [Block] = []
        for para in paragraphs {
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("# ") {
                result.append(Block(kind: .heading1, text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("## ") {
                result.append(Block(kind: .heading2, text: String(trimmed.dropFirst(3))))
            } else {
                result.append(Block(kind: .paragraph, text: trimmed))
            }
        }
        return result
    }
}

/// 加模組選單項（web MODULES）。
struct ModuleMenuItem: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let locked: Bool

    static let all: [ModuleMenuItem] = [
        .init(id: "text", name: String(localized: "文字"), symbol: "textformat", locked: false),
        .init(id: "todo", name: String(localized: "待辦"), symbol: "checklist", locked: false),
        .init(id: "heading", name: String(localized: "標題"), symbol: "text.alignleft", locked: false),
        .init(id: "mindmap", name: String(localized: "心智圖"), symbol: "brain", locked: true),
        .init(id: "ai", name: String(localized: "AI 分析"), symbol: "sparkles", locked: true),
    ]
}
