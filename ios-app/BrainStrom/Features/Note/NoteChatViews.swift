import SwiftUI

// ============================================================
// 筆記頁 · 聊天面板（NoteScreen 的拆分）—— 氣泡串流／token／proposal／⚡重播
// ============================================================

extension NoteScreen {

    func chatPanel(_ doc: NoteDocument) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left").font(.system(size: 14)).foregroundStyle(palette.orange)
                Text(String(localized: "問 AI · 這則筆記"))
                    .font(Tokens.Fonts.body(13, weight: .bold)).foregroundStyle(palette.print)
                Spacer()
                if doc.nudge.state != .pending {
                    Button { chatVM?.sparkReplay(doc) } label: {
                        Text(verbatim: "⚡").font(.system(size: 13))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(palette.orangeDim)
                                .overlay(Circle().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
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
                .lineLimit(1...4)
                .padding(.horizontal, 11)
                .frame(minHeight: 40, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.input)
                        .fill(palette.recess)
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.input)
                            .strokeBorder(palette.line, lineWidth: 1))
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
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 16)
            .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
        }
        .frame(height: 360)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(palette.panel)
                .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        )
        .transition(.move(edge: .bottom))
    }

    func sendChat(_ doc: NoteDocument) {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput = ""
        chatVM?.send(doc, text: text)
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
            Text(bubble.text.isEmpty ? String(localized: "思考中…") : bubble.text)
                .font(Tokens.Fonts.body(13.5))
                .foregroundStyle(isUser ? palette.orangeInk : palette.print)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isUser ? palette.orange : palette.panel2))
            if let tokens = bubble.tokens {
                Text(tokens).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
            if !bubble.proposals.isEmpty {
                proposalRow(bubble.proposals, doc)
            }
            if bubble.stopped {
                Text(String(localized: "（已停止）")).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    func proposalRow(_ items: [ProposalItem], _ doc: NoteDocument) -> some View {
        let locked: Set<String> = ["find_github", "find_youtube", "find_info"]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                    let isLocked = locked.contains(item.action)
                    Button {
                        if isLocked { root.toast.show(String(localized: "即將推出")); return }
                        switch item.action {
                        case "structure": showChat = false; noteVM?.runStructure(doc)
                        case "edit_text": noteVM?.runApplyEdit(doc, instruction: item.instruction ?? item.label)
                        default: root.toast.show(String(localized: "即將推出"))
                        }
                    } label: {
                        Text((isLocked ? "🔒 " : "") + item.label)
                            .font(Tokens.Fonts.body(11.5, weight: .semibold))
                            .foregroundStyle(isLocked ? palette.print3 : palette.orange)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(palette.orangeDim)
                                .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
