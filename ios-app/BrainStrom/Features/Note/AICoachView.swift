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
    @Environment(\.openURL) private var openURL

    @State private var doc: NoteDocument?
    @State private var chatVM: ChatViewModel?
    @State private var noteVM: NoteViewModel?
    @State private var input = ""
    @State private var didAutoKickoff = false
    @State private var competitorResults: [CompetitorItem] = []
    @State private var findingCompetitors = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            chatList
            competitorBar
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
                // 進度「X/核心4」——核心4=一句話/目標用戶/痛點/核心功能
                let filled = doc?.systemSpec.coreFilledCount ?? 0
                Text(String(format: String(localized: "身份證核心 %d/4 · 引導你想清楚"), filled))
                    .font(Tokens.Fonts.body(11)).foregroundStyle(filled >= 4 ? palette.ledGreen : palette.print3)
            }
            Spacer()
            Button {
                Haptics.press(); kickoff()
            } label: {
                Text((chatVM?.messages.isEmpty ?? true) ? String(localized: "⚡ 開始引導") : String(localized: "↻ 重新引導"))
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
                } else if chatVM?.streamingBubbleID == bubble.id {
                    // 串流中：純文字逐字播放（不在串流時 parse markdown，避免整塊重排「五字一排」）
                    let shown = chatVM?.typewriter.shown ?? ""
                    if shown.isEmpty {
                        Text(chatVM?.coachStatus ?? String(localized: "思考中…")).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print2)
                    } else {
                        Text(shown).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                    let locked = bubble.proposalsUsed || chatVM?.streaming == true
                    Button { tapProposal(item, bubble) } label: {
                        Text(item.label)
                            .font(Tokens.Fonts.body(11.5, weight: .semibold))
                            .foregroundStyle(palette.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(palette.orangeDim)
                                .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                            .opacity(locked ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)   // build9 安全鎖②：AI 串流中不可點，避免 send 被 !streaming 靜默丟
                }
            }
        }
    }

    private func tapProposal(_ item: ProposalItem, _ bubble: ChatBubble) {
        chatVM?.markProposalsUsed(bubble.id)
        switch item.action {
        case "update_spec":
            // build9：點候選 → 記入身份證；成功才把它當「我的回答」送出，觸發教練問下一題。
            if let doc, noteVM?.applySpecPatch(doc, instructionJSON: item.instruction) == true {
                chatVM?.send(doc, text: item.label, project: doc.projectContext(), mode: "guided")
            }
        default:
            // structure / edit_text / find_* 屬單篇筆記操作 → 引導去開發筆記分頁
            root.toast.show(String(localized: "這個操作請到「開發筆記」分頁進行"))
        }
    }

    // MARK: - 競品條（資訊夠時浮現；找競品 + 點卡記入）

    @ViewBuilder
    private var competitorBar: some View {
        // build11：门槛放低——只要专案有名字就能找竞品(不用等填满核心3)。
        if let d = doc, !d.title.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if competitorResults.isEmpty {
                    Button { findCompetitors() } label: {
                        HStack(spacing: 6) {
                            if findingCompetitors { ProgressView().controlSize(.mini).tint(palette.orange) }
                            Text(findingCompetitors ? String(localized: "搜尋競品中…")
                                 : String(localized: "🔍 幫你找競品 / 文章 / 開源"))
                                .font(Tokens.Fonts.body(12, weight: .semibold)).foregroundStyle(palette.orange)
                        }
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(Capsule().fill(palette.orangeDim)
                            .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                    }
                    .buttonStyle(.plain).disabled(findingCompetitors)
                    .accessibilityIdentifier("coach.findcompetitors")
                } else {
                    // build12：竞品产品 / 相关文章 / 相关开源 分三排——它们不是同一种东西。
                    let apps = competitorResults.filter { $0.source == "web" || $0.source == "app_store" }
                    let articles = competitorResults.filter { $0.source == "article" }
                    let repos = competitorResults.filter { $0.source == "github" }
                    competitorGroup(String(localized: "🥊 競品產品"), apps, d)
                    competitorGroup(String(localized: "📄 相關文章"), articles, d)
                    competitorGroup(String(localized: "🧰 相關開源（可參考）"), repos, d)
                    // build11：findSimilar——拿第一个竞品「找更多类似的」
                    if let first = apps.first {
                        Button { findSimilarTo(first.url) } label: {
                            Text(findingCompetitors ? String(localized: "搜尋中…") : String(localized: "↻ 找更多像「\(first.title.prefix(8))」的"))
                                .font(Tokens.Fonts.body(11, weight: .semibold)).foregroundStyle(palette.print2)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().strokeBorder(palette.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain).disabled(findingCompetitors)
                        .accessibilityIdentifier("coach.findsimilar")
                    }
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
    }

    @ViewBuilder
    private func competitorGroup(_ title: String, _ items: [CompetitorItem], _ d: NoteDocument) -> some View {
        if !items.isEmpty {
            Text(title).font(Tokens.Fonts.mono(10, weight: .semibold)).foregroundStyle(palette.print3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.url) { c in competitorChip(c, d) }
                }
            }
        }
    }

    private func competitorChip(_ c: CompetitorItem, _ d: NoteDocument) -> some View {
        Button {
            // build12：文章=只開瀏覽器看,不記入身份證競品列;產品/開源=維持記入。
            if c.source == "article" {
                if let u = URL(string: c.url) { openURL(u) }
            } else {
                d.addCompetitors([c]); competitorResults.removeAll { $0.url == c.url }
                root.toast.show(String(localized: "已記入競品"))
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: { switch c.source { case "github": return "🐙"; case "article": return "📄"; default: return "" } }()).font(.system(size: 11))
                    Text(c.title).font(Tokens.Fonts.body(11.5, weight: .semibold)).foregroundStyle(palette.print).lineLimit(1)
                }
                Text(c.summary ?? c.subtitle ?? "").font(Tokens.Fonts.body(9.5)).foregroundStyle(palette.print3).lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(palette.panel2)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func findSimilarTo(_ url: String) {
        guard !findingCompetitors else { return }
        findingCompetitors = true
        Task {
            let items = (try? await root.ai.findSimilar(url: url)) ?? []
            findingCompetitors = false
            if items.isEmpty { root.toast.show(String(localized: "暫時沒找到更多類似的")) }
            else { competitorResults = items }
        }
    }

    private func findCompetitors() {
        guard let d = doc, !findingCompetitors else { return }
        // build9：用「短關鍵字」(產品名/目標用戶取詞)而非整句 oneLiner，否則搜出無關結果。
        let s = d.systemSpec
        let keywords = [s.name, s.targetUser, d.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? d.title
        findingCompetitors = true
        Task {
            let items = (try? await root.ai.findCompetitors(keywords: keywords)) ?? []
            findingCompetitors = false
            if items.isEmpty { root.toast.show(String(localized: "暫時沒找到，稍後再試")) }
            else { competitorResults = items }
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
        if chatVM?.messages.isEmpty == false { chatVM?.reset() }   // 重新引導：先清空再開
        // 引導式訪談：拿專案名稱/靈感（＝主筆記標題）當第一句話開場。
        chatVM?.coachOpen(d, seed: d.title, project: d.projectContext(), mode: "guided")
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let d = ensureDoc() else { return }
        input = ""
        chatVM?.send(d, text: text, project: d.projectContext(), mode: "guided")
    }

    /// 把教練回覆追加進主筆記（appendFromContinue 會自動切塊）。
    private func addToNote(_ text: String) {
        guard let d = ensureDoc() else { return }
        d.appendFromContinue(text)
        root.toast.show(String(localized: "已加入主筆記"))
    }
}
