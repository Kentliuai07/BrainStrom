import SwiftUI

// ============================================================
// P2 · 筆記頁（活文件）—— 佈局 1:1 對齊 web note()：
// nav(返回/文章卡片/undo/redo/可見性) → content(文章/卡片)
// → dock(💬/✦/▦/🗑/已儲存) → fab → dial → chatpanel → ailock
// 本地編輯可用；AI 三鈕未接後端時提示（照 web 非 real 行為）。工業橘皮不變。
// ============================================================

struct NoteScreen: View {

    let systemID: UUID

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var doc: NoteDocument?
    @State private var showDial = false
    @State private var showChat = false
    @State private var chatInput = ""
    @FocusState private var chatFocused: Bool

    var body: some View {
        Group {
            if let doc {
                content(doc)
            } else {
                Color.clear.onAppear(perform: load)
            }
        }
        .background(palette.bg)
        .navigationBarHidden(true)
        .onAppear(perform: load)
    }

    private func load() {
        guard doc == nil, let repo = root.repository else { return }
        doc = NoteDocument(systemID: systemID, repository: repo)
    }

    // MARK: - 主體

    private func content(_ doc: NoteDocument) -> some View {
        VStack(spacing: 0) {
            navBar(doc)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if doc.view == .article {
                        ArticleView(doc: doc)
                    } else {
                        CardsView(doc: doc, runStructure: aiNeedsBackend)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.top, Tokens.Spacing.s4)
                .padding(.bottom, 24)
            }
            dock(doc)
        }
        .overlay(alignment: .bottomTrailing) {
            if !showChat { fab(doc) }
        }
        .overlay { if showDial { dialLayer(doc) } }
        .overlay(alignment: .bottom) { if showChat { chatPanel } }
    }

    // MARK: - 頂欄 nav

    private func navBar(_ doc: NoteDocument) -> some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "系統")).font(Tokens.Fonts.body(15, weight: .semibold))
                }
                .foregroundStyle(palette.orange)
            }
            Spacer()
            viewSeg(doc)
            Spacer()
            histButton("arrow.uturn.backward", enabled: doc.canUndo) {
                let ok = doc.undo(); root.toast.show(ok ? String(localized: "已撤銷一步") : String(localized: "沒有可撤銷的步驟"))
            }
            histButton("arrow.uturn.forward", enabled: doc.canRedo) {
                let ok = doc.redo(); root.toast.show(ok ? String(localized: "已重做一步") : String(localized: "沒有可重做的步驟"))
            }
            Button { doc.toggleVisibility() } label: {
                VisibilityPill(visibility: doc.visibility)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(palette.panel.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    private func viewSeg(_ doc: NoteDocument) -> some View {
        HStack(spacing: 2) {
            segButton(String(localized: "文章"), on: doc.view == .article) { doc.setView(.article) }
            segButton(String(localized: "卡片"), on: doc.view == .cards, enabled: doc.docStateIsCarded) {
                if doc.docStateIsCarded { doc.setView(.cards) } else { root.toast.show(String(localized: "先按 AI 結構化")) }
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.recess)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.line, lineWidth: 1)))
        .frame(maxWidth: 130)
    }

    private func segButton(_ label: String, on: Bool, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Fonts.body(12, weight: .bold))
                .foregroundStyle(on ? palette.orangeInk : (enabled ? palette.print2 : palette.print3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(on ? palette.orange : .clear))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
    }

    private func histButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.print2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(palette.panel2).overlay(Circle().strokeBorder(palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    // MARK: - 底部 dock

    private func dock(_ doc: NoteDocument) -> some View {
        HStack(spacing: 10) {
            dockIcon("bubble.left", accent: true, disabled: doc.naming) {
                Haptics.tap(); showChat.toggle()
            }
            dockKey("✦", disabled: doc.naming) { aiNeedsBackend() }
            dockKey("▦", disabled: doc.naming) { aiNeedsBackend() }
            dockIcon("trash", accent: false, disabled: false) {
                deleteSystem()
            }
            Spacer()
            if doc.savedFlash {
                Text(String(localized: "已儲存"))
                    .font(Tokens.Fonts.mono(10, weight: .semibold))
                    .foregroundStyle(palette.print3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(height: 74)
        .background(palette.panel.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    private func dockIcon(_ symbol: String, accent: Bool, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent ? palette.orange : palette.print2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(palette.panel)
                    .overlay(Circle().strokeBorder(accent ? palette.orange.opacity(0.5) : palette.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }

    private func dockKey(_ glyph: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: glyph).font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.keycap(.orange, cornerRadius: 12))
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }

    // MARK: - FAB + 加模組 dial

    private func fab(_ doc: NoteDocument) -> some View {
        Button {
            Haptics.press(); showDial = true
        } label: {
            Image(systemName: "plus").font(.system(size: 22, weight: .light)).frame(width: 52, height: 52)
        }
        .buttonStyle(.keycap(.orange, cornerRadius: 16))
        .opacity(doc.naming ? 0.45 : 1)
        .disabled(doc.naming)
        .padding(.trailing, 18)
        .padding(.bottom, 90)
    }

    private func dialLayer(_ doc: NoteDocument) -> some View {
        ZStack(alignment: .bottomTrailing) {
            palette.scrim.ignoresSafeArea()
                .onTapGesture { showDial = false }
            VStack(alignment: .trailing, spacing: 8) {
                Text(String(localized: "加模組 · 氛圍開發"))
                    .font(Tokens.Fonts.mono(10, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(palette.print3)
                ForEach(ModuleMenuItem.all) { item in
                    dialItem(item, doc)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 150)
        }
        .transition(.opacity)
    }

    private func dialItem(_ item: ModuleMenuItem, _ doc: NoteDocument) -> some View {
        Button {
            if item.locked { root.toast.show(String(localized: "AI 模組：階段二")); return }
            Haptics.press()
            doc.insertModule(item.id)
            showDial = false
            root.toast.show(String(format: String(localized: "已插入「%@」"), item.name))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.orange)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9).fill(palette.orangeDim))
                Text(item.name).font(Tokens.Fonts.body(14, weight: .medium)).foregroundStyle(palette.print)
                if item.locked {
                    Text(String(localized: "階段二")).font(Tokens.Fonts.mono(8, weight: .semibold)).foregroundStyle(palette.print3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minWidth: 160, alignment: .leading)
            .background(NotchedRectangle(notch: 10).fill(palette.panel)
                .overlay(NotchedRectangle(notch: 10).strokeBorder(palette.orange.opacity(0.32), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .opacity(item.locked ? 0.55 : 1)
    }

    // MARK: - 聊天面板（佈局；送出先提示需真後端）

    private var chatPanel: some View {
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

            VStack {
                Spacer()
                Text(String(localized: "問我這則筆記的內容，例如「這則在講什麼？」"))
                    .font(Tokens.Fonts.body(12)).foregroundStyle(palette.print3)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)

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
                Button { sendChat() } label: {
                    Text(String(localized: "送出")).font(Tokens.Fonts.body(13, weight: .semibold))
                        .frame(width: 56, height: 40)
                }
                .buttonStyle(.keycap(.orange, cornerRadius: 10))
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

    // MARK: - 動作

    private func aiNeedsBackend() {
        root.toast.show(String(localized: "此功能需要真後端（尚未整合）"))
    }

    private func sendChat() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput = ""
        chatFocused = false
        // 步驟 7 接真後端後改為串流；目前先提示
        root.toast.show(String(localized: "聊天於接真後端後啟用（步驟 7）"))
    }

    private func deleteSystem() {
        Haptics.warning()
        try? root.repository?.deleteSystem(id: systemID)
        root.toast.show(String(localized: "已刪除系統"))
        dismiss()
    }
}

#Preview("P2 筆記頁") {
    NavigationStack {
        NoteScreen(systemID: UUID())
    }
    .environment(CompositionRoot())
    .environment(\.palette, .matteBlack)
}
