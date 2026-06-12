import SwiftUI

// ============================================================
// AI 教練（階段三 第 4 刀）—— 看得到「整個專案」（身份證＋所有筆記摘要）
// 兩種玩法靠後端 kickoff 旗標分流：⚡ 引導發想（扩散）／一般提問（收斂）。
// 教練絕不直接改東西，只透過 proposal 建議鈕；update_spec 點了就記入系統結構。
// 沿用 ChatViewModel 串流 + ProjectContext 三層切片（省 token）。
// ============================================================

struct AICoachView: View {

    let systemID: UUID
    /// 新建專案＝true：active 時自動開場。
    var autoKickoff: Bool = false
    /// 此分頁是否在前台（ZStack 三頁同掛載，靠這個避免非當前頁誤觸自動開場）。
    var active: Bool = false

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var doc: NoteDocument?
    @State private var chatVM: ChatViewModel?
    @State private var noteVM: NoteViewModel?
    @State private var input = ""
    @State private var didAutoKickoff = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            chatList
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .onAppear {
            if chatVM == nil { chatVM = ChatViewModel(ai: root.ai, toast: root.toast) }
            if noteVM == nil { noteVM = NoteViewModel(ai: root.ai, toast: root.toast) }
            maybeAutoKickoff()
        }
        .onChange(of: active) { _, _ in maybeAutoKickoff() }
        .onDisappear { chatVM?.stop() }
    }

    // MARK: - 標頭（⚡ 開場）

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: "🤖").font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "AI 教練"))
                    .font(Tokens.Fonts.display(19, weight: .heavy)).foregroundStyle(palette.print)
                Text(String(localized: "看得到整個專案 · 陪你想清楚"))
                    .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
            }
            Spacer()
            Button {
                Haptics.press(); kickoff()
            } label: {
                Text(String(localized: "⚡ 開場"))
                    .font(Tokens.Fonts.body(12.5, weight: .semibold))
                    .padding(.horizontal, 12).frame(height: 34)
            }
            .buttonStyle(.keycap(.orange, cornerRadius: 10))
            .disabled(chatVM?.streaming == true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    // MARK: - 對話串

    private var chatList: some View {
        ScrollView {
            let msgs = chatVM?.messages ?? []
            if msgs.isEmpty {
                VStack(spacing: 10) {
                    Text(verbatim: "🤖").font(.system(size: 36)).opacity(0.5)
                    Text(String(localized: "按「⚡ 開場」讓教練看看這個專案，\n或直接在下面問它問題。"))
                        .font(Tokens.Fonts.body(13)).foregroundStyle(palette.print3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                VStack(spacing: 8) {
                    ForEach(msgs) { bubble in bubbleView(bubble) }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bubbleView(_ bubble: ChatBubble) -> some View {
        let isUser = bubble.role == .user
        return VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
            Group {
                if isUser {
                    Text(bubble.text).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.orangeInk)
                } else if bubble.text.isEmpty {
                    Text(String(localized: "思考中…")).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print2)
                } else {
                    MarkdownView(blocks: MarkdownParser.parse(bubble.text))
                }
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 14).fill(isUser ? palette.orange : palette.panel2))
            if let tokens = bubble.tokens {
                Text(tokens).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
            if !bubble.proposals.isEmpty { proposalRow(bubble) }
            // 📝 加入筆記：把這則教練回覆追加進主筆記（前端就地，零後端）。
            if !isUser && !bubble.text.isEmpty {
                Button { addToNote(bubble.text) } label: {
                    Text(String(localized: "📝 加入筆記"))
                        .font(Tokens.Fonts.body(11.5, weight: .semibold))
                        .foregroundStyle(palette.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(palette.orangeDim)
                            .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.addnote")
            }
            if bubble.stopped {
                Text(String(localized: "（已停止）")).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func proposalRow(_ bubble: ChatBubble) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(bubble.proposals.prefix(4).enumerated()), id: \.offset) { _, item in
                    Button { tapProposal(item, bubble) } label: {
                        Text(item.label)
                            .font(Tokens.Fonts.body(11.5, weight: .semibold))
                            .foregroundStyle(palette.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(palette.orangeDim)
                                .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                            .opacity(bubble.proposalsUsed ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(bubble.proposalsUsed)
                }
            }
        }
    }

    private func tapProposal(_ item: ProposalItem, _ bubble: ChatBubble) {
        chatVM?.markProposalsUsed(bubble.id)
        switch item.action {
        case "update_spec":
            if let doc { noteVM?.applySpecPatch(doc, instructionJSON: item.instruction) }
        default:
            // structure / edit_text / find_* 屬單篇筆記操作 → 引導去開發筆記分頁
            root.toast.show(String(localized: "這個操作請到「開發筆記」分頁進行"))
        }
    }

    // MARK: - 輸入列

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(text: $input, axis: .vertical) {
                Text(String(localized: "問教練關於這個專案…"))
            }
            .font(Tokens.Fonts.body(14)).foregroundStyle(palette.print)
            .focused($inputFocused)
            .lineLimit(1...4)
            .padding(.horizontal, 11).frame(minHeight: 40, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.input).fill(palette.recess)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.input).strokeBorder(palette.line, lineWidth: 1)))
            if chatVM?.streaming == true {
                Button { chatVM?.stop() } label: {
                    Text(String(localized: "停止")).font(Tokens.Fonts.body(13, weight: .semibold)).frame(width: 56, height: 40)
                }
                .buttonStyle(.keycap(.danger, cornerRadius: 10))
            } else {
                Button { send() } label: {
                    Text(String(localized: "送出")).font(Tokens.Fonts.body(13, weight: .semibold)).frame(width: 56, height: 40)
                }
                .buttonStyle(.keycap(.orange, cornerRadius: 10))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    // MARK: - 動作

    /// 惰性取得錨點筆記（系統的主文件；無則建立）。只在真要呼叫 AI 時才碰，避免空逛就建筆記。
    @discardableResult
    private func ensureDoc() -> NoteDocument? {
        if let doc { return doc }
        guard let repo = root.repository,
              let note = try? repo.documentNote(for: systemID),
              let d = NoteDocument(noteID: note.id, repository: repo) else { return nil }
        doc = d
        return d
    }

    /// 自動開場三重閘：要 autoKickoff、要在前台、還沒開過、且沒有對話歷史。
    private func maybeAutoKickoff() {
        guard autoKickoff, active, !didAutoKickoff,
              chatVM?.streaming != true, (chatVM?.messages.isEmpty ?? true) else { return }
        didAutoKickoff = true
        kickoff()
    }

    private func kickoff() {
        guard let d = ensureDoc() else { return }
        // 拿專案名稱/靈感（＝主筆記標題）當第一句話開場。
        chatVM?.coachOpen(d, seed: d.title, project: d.projectContext())
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let d = ensureDoc() else { return }
        input = ""
        chatVM?.send(d, text: text, project: d.projectContext())
    }

    /// 把教練回覆追加進主筆記（appendFromContinue 會自動切塊）。
    private func addToNote(_ text: String) {
        guard let d = ensureDoc() else { return }
        d.appendFromContinue(text)
        root.toast.show(String(localized: "已加入主筆記"))
    }
}
