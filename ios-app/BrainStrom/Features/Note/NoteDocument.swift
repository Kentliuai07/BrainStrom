import Foundation

// ============================================================
// 筆記頁本地文件 store —— 驅動活文件編輯器
// 對齊 web main.js note()；版本指針法（《整合契約 §4》）取代記憶體 undo。
// AI（✦/▦/💬）先不接後端（步驟 7）。
// ============================================================

/// 整批快照（版本鏈存這個的 JSON；含軟刪塊以便復活）。
private struct DocSnapshot: Codable {
    var title: String
    var docStateRaw: String
    var blocks: [Block]
}

@MainActor
@Observable
final class NoteDocument {

    enum ViewMode { case article, cards }

    let systemID: UUID
    private let repository: any NotesRepositoring

    private(set) var noteID: UUID
    var title: String
    private(set) var blocks: [Block]          // 全部塊（含軟刪，供快照）
    private(set) var docState: DocState
    private(set) var visibility: Visibility

    var view: ViewMode = .article
    private(set) var naming: Bool = false
    var savedFlash = false

    // AI 狀態（hash gate / 結構化 / 助攻）
    private(set) var lastAiHash: String?
    private(set) var aiRestructureCount = 0
    private(set) var structuredAt: Date?
    private(set) var nudge = Nudge()

    // 版本指針法 → ↶↷ 可用狀態（由倉儲驅動）。
    private(set) var canUndo = false
    private(set) var canRedo = false

    init?(systemID: UUID, repository: any NotesRepositoring) {
        self.systemID = systemID
        self.repository = repository
        guard let note = try? repository.documentNote(for: systemID) else { return nil }
        self.noteID = note.id
        self.title = note.title
        self.blocks = note.blocks.sorted { $0.orderIndex < $1.orderIndex }
        self.docState = note.docState
        self.lastAiHash = note.lastAiHash
        self.aiRestructureCount = note.aiRestructureCount
        self.structuredAt = note.structuredAt
        self.nudge = note.nudge
        let system = (try? repository.systems())?.first { $0.id == systemID }
        self.visibility = system?.visibility ?? .private
        self.naming = Self.isNamingGate(title: note.title, blocks: liveBlocksOf(self.blocks))
        if view == .cards && docState != .carded { view = .article }
        seedInitialVersionIfNeeded()
        refreshVersionState()
    }

    /// 給 UI 的塊（濾掉軟刪、依序）。
    var orderedBlocks: [Block] { liveBlocksOf(blocks) }

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
        let zero = orderedBlocks.isEmpty
        if v.isEmpty {
            if !zero {
                if title != "未命名系統" { title = "未命名系統"; persist(trigger: "cardEdit") }
            } else {
                title = ""
                if !naming { naming = true }
                persist(trigger: nil)
            }
            return
        }
        if v != title { title = v; persist(trigger: "cardEdit") }
        if naming { naming = false }
    }

    func quickName() -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        let name = f.string(from: .now) + " " + String(localized: "隨手記")
        commitTitle(name)
        return name
    }

    // MARK: - 塊編輯

    func editBlockText(_ id: UUID, to text: String) {
        guard let i = blocks.firstIndex(where: { $0.id == id }), blocks[i].text != text else { return }
        blocks[i].text = text
        blocks[i].aiHash = nil       // 內容變了，指紋作廢（diff 會視為 changed）
        persist(trigger: "cardEdit")
    }

    func toggleTodo(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[i].isDone.toggle()
        persist(trigger: "cardEdit")
    }

    func togglePin(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[i].isPinned.toggle()
        persist(trigger: nil)        // 釘選不落版本（同網頁）
    }

    func move(_ id: UUID, by step: Int) {
        let live = orderedBlocks
        guard let liveIdx = live.firstIndex(where: { $0.id == id }) else { return }
        let target = liveIdx + step
        guard target >= 0 && target < live.count else { return }
        // 在全陣列中交換這兩個 live 塊的 orderIndex
        let aID = live[liveIdx].id, bID = live[target].id
        guard let ai = blocks.firstIndex(where: { $0.id == aID }),
              let bi = blocks.firstIndex(where: { $0.id == bID }) else { return }
        let tmp = blocks[ai].orderIndex
        blocks[ai].orderIndex = blocks[bi].orderIndex
        blocks[bi].orderIndex = tmp
        blocks.sort { $0.orderIndex < $1.orderIndex }
        persist(trigger: "cardEdit")
    }

    /// 刪除＝軟刪（寫 deletedAt；undo 可復活）。
    func delete(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }), !blocks[i].isDeleted else { return }
        blocks[i].deletedAt = .now
        persist(trigger: "delete")
    }

    func appendFromContinue(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var nextOrder = (blocks.map(\.orderIndex).max() ?? -1) + 1
        for seg in Algo.splitIntoBlocks(text) {
            var b = seg
            b.orderIndex = nextOrder
            nextOrder += 1
            blocks.append(b)
        }
        persist(trigger: "cardEdit")
    }

    func insertModule(_ moduleID: String) {
        let kind: BlockKind
        var module: ModuleKind?
        switch moduleID {
        case "todo": kind = .todo
        case "heading": kind = .heading1
        case "text": kind = .paragraph
        default: kind = .module; module = ModuleKind(rawValue: moduleID)
        }
        let order = (blocks.map(\.orderIndex).max() ?? -1) + 1
        let block = Block(kind: kind, text: "", isPinned: kind == .module,
                          moduleKind: module, orderIndex: order,
                          source: .manual)
        blocks.append(block)
        persist(trigger: kind == .module ? "addModule" : "cardEdit")
    }

    func toggleVisibility() {
        visibility = visibility == .private ? .public : .private
        try? repository.setVisibility(systemID: systemID, to: visibility)
    }

    func setView(_ v: ViewMode) {
        if v == .cards && docState != .carded { return }
        view = v
    }

    // MARK: - Undo / Redo（版本指針法，倉儲落盤；殺 App 重開仍在）

    @discardableResult
    func undo() -> Bool {
        guard let data = try? repository.undoVersion(noteID: noteID) else { return false }
        applySnapshot(data)
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let data = try? repository.redoVersion(noteID: noteID) else { return false }
        applySnapshot(data)
        return true
    }

    private func applySnapshot(_ data: Data) {
        guard let snap = try? JSONDecoder().decode(DocSnapshot.self, from: data) else { return }
        title = snap.title
        docState = DocState(rawValue: snap.docStateRaw) ?? .raw
        blocks = snap.blocks.sorted { $0.orderIndex < $1.orderIndex }   // 含軟刪塊：原 id 覆寫、復活
        naming = Self.isNamingGate(title: title, blocks: orderedBlocks)
        if view == .cards && docState != .carded { view = .article }
        saveNote()
        refreshVersionState()
    }

    // MARK: - 持久化

    private func seedInitialVersionIfNeeded() {
        guard (try? repository.hasVersions(noteID: noteID)) == false else { return }
        if let data = snapshotData() {
            try? repository.commitVersion(noteID: noteID, snapshot: data, trigger: "open")
        }
    }

    private func reindex() {
        // 維持 live 塊連續 orderIndex（軟刪塊保留原位即可）
        var i = 0
        for idx in blocks.indices where !blocks[idx].isDeleted {
            blocks[idx].orderIndex = i; i += 1
        }
    }

    /// trigger != nil 時同時落一個版本（commit-after-change）。
    private func persist(trigger: String?) {
        reindex()
        naming = Self.isNamingGate(title: title, blocks: orderedBlocks)
        saveNote()
        if let trigger, let data = snapshotData() {
            try? repository.commitVersion(noteID: noteID, snapshot: data, trigger: trigger)
            refreshVersionState()
        }
        flashSaved()
    }

    private func saveNote() {
        let note = Note(id: noteID, systemID: systemID, title: title,
                        docState: docState, blocks: blocks, updatedAt: .now,
                        lastAiHash: lastAiHash, aiRestructureCount: aiRestructureCount,
                        structuredAt: structuredAt, nudge: nudge)
        try? repository.saveNote(note)
        try? repository.renameSystem(id: systemID, name: title)
    }

    // MARK: - AI 套用（步驟7：ViewModel 收完串流後呼叫）

    /// 目前可整理的變動塊（diff 省錢閘）。
    func changedBlockIds() -> Set<UUID> { Algo.diffBlocks(blocks) }

    /// hash gate：整篇沒變 → 跳過 AI。
    var shouldSkipOptimize: Bool { Algo.shouldSkipAi(lastAiHash: lastAiHash, blocks: blocks) }

    /// 組 AI 傳輸 payload（changed 標記＝diff 結果或 instruction 全未釘選 DIFF）。
    func payload(changedIds: Set<UUID>) -> NotePayload {
        NotePayload(title: title, blocks: orderedBlocks.map { block in
            NotePayload.BlockPayload(
                id: block.id.uuidString,
                type: payloadType(block),
                content: block.text,
                pinned: block.isPinned,
                changed: changedIds.contains(block.id),
                module: block.kind == .module)
        })
    }

    /// applyEdit 用：全部未釘選 DIFF_TYPES 塊 id。
    func editableIds() -> Set<UUID> {
        Set(orderedBlocks.filter { Algo.isDiffType($0.kind) && !$0.isPinned }.map(\.id))
    }

    /// 套用優化 patch；拒絕回原因（零變動），成功回 nil。
    @discardableResult
    func applyOptimize(patch: OptimizePatch, changedIds: Set<UUID>, mode: OptimizeMode) -> PatchRejection? {
        switch Algo.applyOptimizePatch(blocks: blocks, patch: patch, changedIds: changedIds,
                                       mode: mode, docState: docState, now: Date()) {
        case .rejected(let reason):
            return reason
        case .applied(let newBlocks, let hash, let state):
            blocks = newBlocks
            docState = state
            lastAiHash = hash
            aiRestructureCount += 1
            structuredAt = Date()
            persist(trigger: mode == .instruction ? "instruction" : "optimize")
            return nil
        }
    }

    /// 套用結構化卡片；拒絕回原因（零變動），成功回 nil 並切卡片視圖。
    @discardableResult
    func applyStructure(cards: [StructureCard]) -> StructureRejection? {
        switch Algo.applyStructureCards(blocks: blocks, cards: cards) {
        case .rejected(let reason):
            return reason
        case .applied(let newBlocks, let hash):
            blocks = newBlocks
            docState = .carded
            lastAiHash = hash
            aiRestructureCount += 1
            structuredAt = Date()
            persist(trigger: "structure")
            view = .cards
            return nil
        }
    }

    // MARK: - 點子助攻 nudge

    func nudgeFingerprint() -> String { Algo.nudgeHash(title: title, blocks: blocks) }

    func updateNudge(_ transform: (inout Nudge) -> Void) {
        var n = nudge
        transform(&n)
        nudge = n
        saveNote()
    }

    private func payloadType(_ block: Block) -> String {
        switch block.kind {
        case .paragraph: "text"
        case .heading1, .heading2: "heading"
        case .todo: "todo"
        case .module: block.moduleKind?.rawValue ?? "module"
        }
    }

    private func snapshotData() -> Data? {
        try? JSONEncoder().encode(DocSnapshot(title: title, docStateRaw: docState.rawValue, blocks: blocks))
    }

    private func refreshVersionState() {
        let state = (try? repository.versionState(noteID: noteID)) ?? (canUndo: false, canRedo: false)
        canUndo = state.canUndo
        canRedo = state.canRedo
    }

    private func flashSaved() {
        savedFlash = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            savedFlash = false
        }
    }
}

private func liveBlocksOf(_ blocks: [Block]) -> [Block] {
    blocks.filter { !$0.isDeleted }.sorted { $0.orderIndex < $1.orderIndex }
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
