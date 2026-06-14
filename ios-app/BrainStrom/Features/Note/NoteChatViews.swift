import SwiftUI

// ============================================================
// 筆記頁 · 聊天面板（NoteScreen 的拆分）—— 氣泡串流／token／proposal／⚡重播
// ============================================================

extension NoteDetailScreen {

    func chatPanel(_ doc: NoteDocument) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left").font(.system(size: 14)).foregroundStyle(palette.orange)
                Text(String(localized: "問 AI · 這則筆記"))
                    .font(Tokens.Fonts.body(13, weight: .bold)).foregroundStyle(palette.print)
                Spacer()
                Button { showChat = false } label: {
                    Text(String(localized: "收合 ▾")).font(Tokens.Fonts.body(12, weight: .semibold)).foregroundStyle(palette.orange)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }

            chatList(doc)

            HStack(spacing: 8) {
                TextField(text: $chatInput, axis: .vertical) {
                    Text(String(localized: "問這則筆記…"))
                }
                .font(Tokens.Fonts.body(14))
                .foregroundStyle(palette.print)
                .focused($chatFocused)
                .accessibilityIdentifier("chat.input")
                .lineLimit(1...4)
                .padding(.horizontal, 11)
                .frame(minHeight: 40, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input))
                        .fill(palette.recess)
                        .overlay(RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input))
                            .strokeBorder(palette.isHard ? palette.ink : palette.line, lineWidth: palette.metrics.border))
                )
                if chatVM?.streaming == true {
                    Button { chatVM?.stop() } label: {
                        Text(String(localized: "停止")).font(Tokens.Fonts.body(13, weight: .semibold))
                            .frame(width: 56, height: 40)
                    }
                    .buttonStyle(.keycap(.danger, cornerRadius: 10))
                } else {
                    Button { sendChat(doc) } label: {
                        Text(String(localized: "送出")).font(Tokens.Fonts.body(13, weight: .semibold))
                            .frame(width: 56, height: 40)
                    }
                    .buttonStyle(.keycap(.orange, cornerRadius: 10))
                    .accessibilityIdentifier("chat.send")
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 16)
            .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .frame(height: 360)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: palette.radius(20), topTrailingRadius: palette.radius(20))
                .fill(palette.panel)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: palette.radius(20), topTrailingRadius: palette.radius(20)).stroke(palette.isHard ? palette.ink : .clear, lineWidth: palette.metrics.border))
        )
        .cardShadow(palette, shape: UnevenRoundedRectangle(topLeadingRadius: palette.radius(20), topTrailingRadius: palette.radius(20)), softColor: .black.opacity(0.3), softRadius: 12, softY: -4)
        .transition(.move(edge: .bottom))
    }

    func sendChat(_ doc: NoteDocument) {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput = ""
        // build7 · B 模式：单笔记聊天也带 spec 上下文，後端偵測到身份證資訊就抛「記入結構」鈕。
        chatVM?.send(doc, text: text, project: doc.projectContext())
    }

    @ViewBuilder
    func chatList(_ doc: NoteDocument) -> some View {
        let msgs = chatVM?.messages ?? []
        ScrollView {
            if msgs.isEmpty {
                Text(String(localized: "問我這則筆記的內容，例如「這則在講什麼？」"))
                    .font(Tokens.Fonts.body(12)).foregroundStyle(palette.print3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(msgs) { bubble in chatBubbleView(bubble, doc) }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func chatBubbleView(_ bubble: ChatBubble, _ doc: NoteDocument) -> some View {
        let isUser = bubble.role == .user
        return VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
            Group {
                if isUser {
                    Text(bubble.text)
                        .font(Tokens.Fonts.body(13.5))
                        .foregroundStyle(palette.orangeInk)
                } else if chatVM?.streamingBubbleID == bubble.id {
                    // 串流中：純文字逐字播放（不在串流時 parse markdown，避免整塊重排「五字一排」）
                    let shown = chatVM?.typewriter.shown ?? ""
                    if shown.isEmpty {
                        Text(chatVM?.coachStatus ?? String(localized: "思考中…"))
                            .font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print2)
                    } else {
                        Text(shown).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if bubble.text.isEmpty {
                    Text(String(localized: "思考中…"))
                        .font(Tokens.Fonts.body(13.5))
                        .foregroundStyle(palette.print2)
                } else {
                    // AI 回應定稿：markdown 排版（像 Claude.ai）
                    MarkdownView(blocks: MarkdownParser.parse(bubble.text))
                }
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(palette.roundShape(14)
                .fill(isUser ? palette.userBubble : palette.panel2)
                .overlay(palette.roundShape(14).stroke(palette.isHard ? palette.ink : .clear, lineWidth: palette.metrics.border)))
            if let tokens = bubble.tokens {
                Text(tokens).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
            if !bubble.proposals.isEmpty {
                proposalRow(bubble, doc)
            }
            if bubble.stopped {
                Text(String(localized: "（已停止）")).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    func proposalRow(_ bubble: ChatBubble, _ doc: NoteDocument) -> some View {
        let locked: Set<String> = ["find_github", "find_youtube", "find_info"]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(bubble.proposals.prefix(4).enumerated()), id: \.offset) { _, item in
                    let isLocked = locked.contains(item.action)
                    Button {
                        if isLocked { root.toast.show(String(localized: "即將推出")); return }
                        chatVM?.markProposalsUsed(bubble.id)   // 點過整列禁用
                        switch item.action {
                        case "structure": showChat = false; noteVM?.runStructure(doc)
                        case "edit_text": noteVM?.runApplyEdit(doc, instruction: item.instruction ?? item.label)
                        case "update_spec": noteVM?.applySpecPatch(doc, instructionJSON: item.instruction)
                        default: root.toast.show(String(localized: "即將推出"))
                        }
                    } label: {
                        Text((isLocked ? "🔒 " : "") + item.label)
                            .font(Tokens.Fonts.body(11.5, weight: .semibold))
                            .foregroundStyle(isLocked ? palette.print3 : palette.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(palette.pillShape.fill(palette.orangeDim)
                                .overlay(palette.pillShape.stroke(palette.isHard ? palette.ink : palette.orange.opacity(0.3), lineWidth: palette.metrics.border)))
                            .opacity(bubble.proposalsUsed && !isLocked ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(bubble.proposalsUsed && !isLocked)   // 鎖定項仍可點(只 toast)
                }
            }
        }
    }
}
