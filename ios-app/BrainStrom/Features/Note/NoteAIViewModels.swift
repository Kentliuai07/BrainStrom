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
    private var task: Task<Void, Never>?

    init(ai: any AIServicing, toast: ToastModel) {
        self.ai = ai
        self.toast = toast
    }

    var hasBackend: Bool { !(ai is AIServiceStub) }

    // MARK: - ✦ 優化

    func requestOptimize(_ doc: NoteDocument) {
        guard !aiBusy else { return }
        if doc.naming { return }
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
        guard !aiBusy, !doc.naming else { return }
        if doc.docStateIsCarded && doc.shouldSkipOptimize {
            toast.show(String(localized: "內容沒變，未消耗 AI")); return
        }
        doc.setView(.cards)
        lock(String(localized: "AI 整理中…"))
        let payload = doc.payload(changedIds: [])
        task = Task { [weak self] in
            guard let self else { return }
            var cards: [StructureCard] = []
            do {
                for try await event in ai.structure(note: payload) {
                    switch event {
                    case .cardDone(_, let card):
                        cards.append(StructureCard(type: card.type, title: card.title,
                                                   content: card.content, absorbed: card.absorbed))
                    case .error(let code, _): unlock(); aiErrorToast(code); return
                    default: break
                    }
                }
                unlock()
                if let reason = doc.applyStructure(cards: cards) {
                    structureToast(reason)
                } else {
                    toast.show(String(format: String(localized: "回傳 %d 張卡"), cards.count))
                }
            } catch is CancellationError {
                unlock()
            } catch {
                unlock(); toast.show(String(localized: "AI 連線出錯，請稍後再試"))
            }
        }
    }

    // MARK: - 對話式編輯（proposal edit_text → applyEdit）

    func runApplyEdit(_ doc: NoteDocument, instruction: String) {
        guard !aiBusy, !doc.naming else { return }
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

    func send(_ doc: NoteDocument, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !streaming else { return }
        messages.append(ChatBubble(role: .user, text: trimmed))
        runStream(doc, history: messages.map { ChatMessage(role: $0.role == .user ? .user : .ai, content: $0.text) },
                  kickoff: false)
    }

    // MARK: - ⚡ 點子助攻

    /// 教練開場：kickoff 串流，開場白＋proposals 存進 nudge.opening 快照。
    func startKickoff(_ doc: NoteDocument) {
        guard !streaming else { return }
        doc.updateNudge { $0.state = .opened; $0.hash = doc.nudgeFingerprint(); $0.at = Date() }
        runStream(doc, history: [], kickoff: true, saveNudge: true)
    }

    /// 面板 ⚡：指紋同 → 零成本注入上次點評；不同 → 重新 kickoff。
    func sparkReplay(_ doc: NoteDocument) {
        guard !streaming else { return }
        let hash = doc.nudgeFingerprint()
        if let opening = doc.nudge.openingText, doc.nudge.hash == hash {
            var bubble = ChatBubble(role: .ai, text: opening)
            bubble.tokens = String(localized: "上次的教練點評（內容沒變，未消耗 AI）")
            bubble.proposals = doc.nudge.openingProposals.map {
                ProposalItem(action: $0.action, label: $0.label, instruction: $0.instruction)
            }
            messages.append(bubble)
        } else {
            doc.updateNudge { $0.state = .opened; $0.hash = hash; $0.at = Date() }
            runStream(doc, history: [], kickoff: true, saveNudge: true)
        }
    }

    private func runStream(_ doc: NoteDocument, history: [ChatMessage], kickoff: Bool, saveNudge: Bool = false) {
        streaming = true
        let aiIndex = messages.count
        messages.append(ChatBubble(role: .ai, text: ""))
        let payload = doc.payload(changedIds: [])
        task = Task { [weak self] in
            guard let self else { return }
            var accumulated = ""
            var captured: [ProposalItem] = []
            do {
                for try await event in ai.chatNote(messages: history, note: payload, kickoff: kickoff) {
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
                if saveNudge && (!accumulated.isEmpty || !captured.isEmpty) {
                    doc.updateNudge {
                        $0.openingText = accumulated
                        $0.openingProposals = captured.map {
                            ProposalSnapshot(action: $0.action, label: $0.label, instruction: $0.instruction)
                        }
                    }
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
}
