import Foundation

// ============================================================
// 筆記頁 AI 控制層（步驟7）—— NoteViewModel(優化/結構化) + ChatViewModel(聊天)
// 串流、進行中鎖定、安全閥結果、省錢提示；UI 只認這兩個 @Observable。
// ============================================================

@MainActor
@Observable
final class NoteViewModel {

    private let ai: any AIServicing
    private let toast: ToastModel

    var aiBusy = false
    var aiLockMessage = ""
    var showOptimizeConfirm = false
    /// 結構化串流中逐張浮現的卡（骨架→填內容）。
    var streamingCards: [StreamingCard] = []
    var structuring = false
    private var task: Task<Void, Never>?

    init(ai: any AIServicing, toast: ToastModel) {
        self.ai = ai
        self.toast = toast
    }

    var hasBackend: Bool { !(ai is AIServiceStub) }

    // MARK: - ✦ 優化

    func requestOptimize(_ doc: NoteDocument) {
        guard !aiBusy else { return }
        if doc.shouldSkipOptimize { toast.show(String(localized: "內容沒變，未消耗 AI")); return }
        if doc.changedBlockIds().isEmpty { toast.show(String(localized: "沒有可優化的變動段落，未消耗 AI")); return }
        showOptimizeConfirm = true
    }

    func confirmOptimize(_ doc: NoteDocument, groupTopics: Bool) {
        showOptimizeConfirm = false
        let changed = doc.changedBlockIds()
        lock(String(localized: "AI 整理中…"))
        let payload = doc.payload(changedIds: changed)
        task = Task { [weak self] in
            guard let self else { return }
            var patch = OptimizePatch()
            var produced = 0
            do {
                for try await event in ai.optimize(note: payload, groupTopics: groupTopics, instruction: nil) {
                    switch event {
                    case .cardDone(_, let card): collect(card, into: &patch); produced += 1
                    case .cardRemoved(let id): patch.removes.append(id)
                    case .error(let code, _): unlock(); aiErrorToast(code); return
                    default: break
                    }
                }
                finishOptimize(doc, patch: patch, changed: changed, mode: .optimize, produced: produced)
            } catch is CancellationError {
                unlock()
            } catch {
                unlock(); toast.show(String(localized: "AI 連線出錯，請稍後再試"))
            }
        }
    }

    func cancelOptimize() { showOptimizeConfirm = false }

    private func finishOptimize(_ doc: NoteDocument, patch: OptimizePatch, changed: Set<UUID>,
                                mode: OptimizeMode, produced: Int) {
        unlock()
        if let reason = doc.applyOptimize(patch: patch, changedIds: changed, mode: mode) {
            safetyToast(reason)
        } else {
            toast.show(String(format: String(localized: "已優化 %d 段"), produced))
        }
    }

    // MARK: - ▦ 結構化

    func runStructure(_ doc: NoteDocument) {
        guard !aiBusy else { return }
        if doc.docStateIsCarded && doc.shouldSkipOptimize {
            toast.show(String(localized: "內容沒變，未消耗 AI")); return
        }
        doc.setView(.cards)
        structuring = true
        streamingCards = []
        lock(String(localized: "AI 整理中…"))
        let payload = doc.payload(changedIds: [])
        task = Task { [weak self] in
            guard let self else { return }
            var cards: [StructureCard] = []
            do {
                for try await event in ai.structure(note: payload) {
                    switch event {
                    case .cardStart(let index, let title, _):
                        streamingCards.append(StreamingCard(index: index, title: title, content: nil))
                    case .cardDone(let index, let card):
                        cards.append(StructureCard(type: card.type, title: card.title,
                                                   content: card.content, absorbed: card.absorbed))
                        if let i = streamingCards.firstIndex(where: { $0.index == index }) {
                            streamingCards[i].title = card.title ?? streamingCards[i].title
                            streamingCards[i].content = card.content ?? ""
                        } else {
                            streamingCards.append(StreamingCard(index: index, title: card.title ?? "",
                                                                content: card.content ?? ""))
                        }
                    case .error(let code, _): structuring = false; unlock(); aiErrorToast(code); return
                    default: break
                    }
                }
                structuring = false
                unlock()
                if let reason = doc.applyStructure(cards: cards) {
                    structureToast(reason)
                } else {
                    toast.show(String(format: String(localized: "回傳 %d 張卡"), cards.count))
                }
            } catch is CancellationError {
                structuring = false; unlock()
            } catch {
                structuring = false; unlock(); toast.show(String(localized: "AI 連線出錯，請稍後再試"))
            }
        }
    }

    /// 結構化串流中的一張卡（content==nil → 骨架）。
    struct StreamingCard: Identifiable, Equatable {
        let id = UUID()
        let index: Int
        var title: String
        var content: String?
    }

    // MARK: - 對話式編輯（proposal edit_text → applyEdit）

    func runApplyEdit(_ doc: NoteDocument, instruction: String) {
        guard !aiBusy else { return }
        let changed = doc.editableIds()
        lock(String(localized: "AI 幫你補內容中…"))
        let payload = doc.payload(changedIds: changed)
        task = Task { [weak self] in
            guard let self else { return }
            var patch = OptimizePatch()
            do {
                for try await event in ai.optimize(note: payload, groupTopics: false, instruction: instruction) {
                    switch event {
                    case .cardDone(_, let card): collect(card, into: &patch)
                    case .cardRemoved(let id): patch.removes.append(id)
                    case .error(let code, _): unlock(); aiErrorToast(code); return
                    default: break
                    }
                }
                unlock()
                if patch.adds.isEmpty && patch.updates.isEmpty && patch.removes.isEmpty {
                    toast.show(String(localized: "AI 沒有提出任何修改")); return
                }
                if let reason = doc.applyOptimize(patch: patch, changedIds: changed, mode: .instruction) {
                    safetyToast(reason)
                } else {
                    toast.show(String(localized: "已幫你補上，可按 ↶ 還原"))
                }
            } catch is CancellationError {
                unlock()
            } catch {
                unlock(); toast.show(String(localized: "AI 連線出錯，請稍後再試"))
            }
        }
    }

    // MARK: - 記入系統身份證（proposal update_spec → 部分合併）

    /// 解析 instruction 內的 JSON 補丁 → 合併進現有身份證（null/缺鍵不動）。
    /// 回傳是否成功（build9 安全鎖①：失敗就別讓教練續聊，否則拿舊 spec 重複問同題）。
    @discardableResult
    func applySpecPatch(_ doc: NoteDocument, instructionJSON: String?) -> Bool {
        guard let json = instructionJSON?.data(using: .utf8),
              let patch = try? JSONDecoder().decode(SpecPatch.self, from: json) else {
            toast.show(String(localized: "身份證資料讀取失敗")); return false
        }
        doc.updateSystemSpec(patch.merged(into: doc.systemSpec))
        toast.show(String(localized: "已記入系統結構"))
        return true
    }

    // MARK: - 控制

    func abort() { task?.cancel(); task = nil; unlock() }

    private func lock(_ message: String) { aiBusy = true; aiLockMessage = message }
    private func unlock() { aiBusy = false }

    private func collect(_ card: CardPayload, into patch: inout OptimizePatch) {
        switch card.action {
        case "add":
            patch.adds.append(.init(type: card.type ?? "text", content: card.content ?? "",
                                    position: card.position ?? 0))
        case "update":
            if let id = card.id { patch.updates.append(.init(id: id, content: card.content ?? "")) }
        default:
            break
        }
    }

    private func aiErrorToast(_ code: String) {
        switch code {
        case "rate_limited": toast.show(String(localized: "AI 暫時忙線，稍等再試"))
        case "bad_request": toast.show(String(localized: "筆記太大，先精簡或拆成兩則"))
        case "unauthorized": toast.show(String(localized: "登入憑證失效，請重新登入"))
        default: toast.show(String(localized: "AI 出錯，請稍後再試"))
        }
    }

    private func safetyToast(_ reason: PatchRejection) {
        toast.show(String(localized: "變動過大，已保留原內容"))
    }

    private func structureToast(_ reason: StructureRejection) {
        toast.show(String(localized: "變動過大，已保留原內容"))
    }
}

/// 聊天氣泡。
struct ChatBubble: Identifiable, Equatable {
    enum Role { case user, ai }
    let id = UUID()
    let role: Role
    var text: String
    var tokens: String?
    var proposals: [ProposalItem] = []
    var proposalsUsed = false
    var stopped = false
}

@MainActor
@Observable
final class ChatViewModel {

    private let ai: any AIServicing
    private let toast: ToastModel

    var messages: [ChatBubble] = []
    var streaming = false
    private var task: Task<Void, Never>?

    init(ai: any AIServicing, toast: ToastModel) {
        self.ai = ai
        self.toast = toast
    }

    /// 切筆記清空（聊天歷史只存記憶體，附錄 D7）。
    func reset() { task?.cancel(); task = nil; messages = []; streaming = false }

    func send(_ doc: NoteDocument, text: String, project: ProjectContext? = nil, mode: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !streaming else { return }
        messages.append(ChatBubble(role: .user, text: trimmed))
        runStream(doc, history: messages.map { ChatMessage(role: $0.role == .user ? .user : .ai, content: $0.text) },
                  kickoff: false, project: project, mode: mode)
    }

    // MARK: - 🤖 AI 教練開場（階段三 v3，專案級；不依賴 nudge）

    /// 拿「名稱/靈感」當第一句話開場：注入成首條 user 訊息 → kickoff 串流。messages 已有內容則不重複開場。
    func coachOpen(_ doc: NoteDocument, seed: String, project: ProjectContext? = nil, mode: String? = nil) {
        guard !streaming, messages.isEmpty else { return }
        let s = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { messages.append(ChatBubble(role: .user, text: s)) }
        let history = messages.map { ChatMessage(role: $0.role == .user ? .user : .ai, content: $0.text) }
        runStream(doc, history: history, kickoff: true, project: project, mode: mode)
    }

    private func runStream(_ doc: NoteDocument, history: [ChatMessage], kickoff: Bool,
                           project: ProjectContext? = nil, mode: String? = nil) {
        streaming = true
        let aiIndex = messages.count
        messages.append(ChatBubble(role: .ai, text: ""))
        let payload = doc.payload(changedIds: [])
        task = Task { [weak self] in
            guard let self else { return }
            var accumulated = ""
            var captured: [ProposalItem] = []
            do {
                for try await event in ai.chatNote(messages: history, note: payload, project: project, mode: mode, kickoff: kickoff) {
                    guard aiIndex < messages.count else { break }
                    switch event {
                    case .delta(let t):
                        accumulated += t; messages[aiIndex].text = accumulated
                    case .usage(let u):
                        messages[aiIndex].tokens = "tokens: in \(u.inputTokens) / out \(u.outputTokens)"
                    case .proposal(let items):
                        captured = items; messages[aiIndex].proposals = items
                    case .error(let code, _):
                        messages[aiIndex].text = accumulated.isEmpty ? String(localized: "AI 出錯：\(code)") : accumulated
                    default: break
                    }
                }
                if aiIndex < messages.count && messages[aiIndex].text.isEmpty && captured.isEmpty {
                    messages.remove(at: aiIndex)   // 一個字都沒吐 → 不留空氣泡
                }
                streaming = false
            } catch is CancellationError {
                if aiIndex < messages.count { messages[aiIndex].stopped = true }
                streaming = false
            } catch {
                streaming = false
                toast.show(String(localized: "AI 連線出錯，請稍後再試"))
            }
        }
    }

    func stop() { task?.cancel() }

    /// proposal 列點過一項 → 整列禁用（防重複）。
    func markProposalsUsed(_ id: UUID) {
        if let i = messages.firstIndex(where: { $0.id == id }) { messages[i].proposalsUsed = true }
    }
}
