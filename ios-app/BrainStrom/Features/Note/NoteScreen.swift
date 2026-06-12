import SwiftUI

// ============================================================
// P2 · 筆記頁（活文件）—— 佈局對齊 web note()：
// nav(返回/文章卡片/undo/redo/可見性) → content(文章/卡片)
// → dock(💬/✦/▦/🗑/已儲存) → fab → dial → chatpanel(另檔) → ailock
// AI 全接真後端（NoteViewModel/ChatViewModel）。工業橘皮不變。
// ============================================================

struct NoteDetailScreen: View {

    let noteID: UUID

    @Environment(CompositionRoot.self) var root
    @Environment(\.palette) var palette
    @Environment(\.dismiss) private var dismiss

    @State private var doc: NoteDocument?
    @State var noteVM: NoteViewModel?
    @State var chatVM: ChatViewModel?
    @State private var showDial = false
    @State var showChat = false
    @State var chatInput = ""
    @FocusState var chatFocused: Bool

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
        .onDisappear {
            noteVM?.abort(); chatVM?.reset()
            if doc?.cleanupEmptyOnLeave() == true { root.toast.show(String(localized: "空筆記已丟棄")) }
        }
    }

    private func load() {
        guard doc == nil, let repo = root.repository else { return }
        doc = NoteDocument(noteID: noteID, repository: repo)
        noteVM = NoteViewModel(ai: root.ai, toast: root.toast)
        chatVM = ChatViewModel(ai: root.ai, toast: root.toast)
    }

    // MARK: - 主體

    private func content(_ doc: NoteDocument) -> some View {
        VStack(spacing: 0) {
            navBar(doc)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 階段三：筆記只負責純寫作；結構卡片移到「系統結構」分頁。
                    ArticleView(doc: doc)
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
        .overlay { if noteVM?.aiBusy == true { aiLockOverlay } }
        .overlay(alignment: .bottom) { if showChat { chatPanel(doc) } }
        .confirmationDialog(String(localized: "要不要順便分主題、加小標題？"),
                            isPresented: Binding(get: { noteVM?.showOptimizeConfirm ?? false },
                                                 set: { if !$0 { noteVM?.cancelOptimize() } }),
                            titleVisibility: .visible) {
            Button(String(localized: "要")) { noteVM?.confirmOptimize(doc, groupTopics: true) }
            Button(String(localized: "不要")) { noteVM?.confirmOptimize(doc, groupTopics: false) }
            Button(String(localized: "取消"), role: .cancel) { noteVM?.cancelOptimize() }
        }
    }

    /// AI 進行中鎖定遮罩（半透明＋頂部進度條＋訊息）。
    private var aiLockOverlay: some View {
        ZStack(alignment: .top) {
            palette.bg.opacity(0.58).ignoresSafeArea()
            ProgressView().frame(maxWidth: .infinity).padding(.top, 2)
                .tint(palette.orange)
            Text(noteVM?.aiLockMessage ?? "")
                .font(Tokens.Fonts.body(13, weight: .bold))
                .foregroundStyle(palette.print)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(palette.panel).overlay(Capsule().strokeBorder(palette.line, lineWidth: 1)))
                .frame(maxHeight: .infinity)
        }
        .transition(.opacity)
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
                    Text(String(localized: "筆記")).font(Tokens.Fonts.body(15, weight: .semibold))
                }
                .foregroundStyle(palette.orange)
            }
            .accessibilityIdentifier("note.back")
            Spacer()
            histButton("arrow.uturn.backward", enabled: doc.canUndo && noteVM?.aiBusy != true) {
                let ok = doc.undo(); root.toast.show(ok ? String(localized: "已撤銷一步") : String(localized: "沒有可撤銷的步驟"))
            }
            .accessibilityIdentifier("note.undo")
            histButton("arrow.uturn.forward", enabled: doc.canRedo && noteVM?.aiBusy != true) {
                let ok = doc.redo(); root.toast.show(ok ? String(localized: "已重做一步") : String(localized: "沒有可重做的步驟"))
            }
            .accessibilityIdentifier("note.redo")
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
            dockIcon("bubble.left", accent: true, disabled: noteVM?.aiBusy == true) {
                Haptics.tap(); showChat.toggle()
            }
            .accessibilityIdentifier("dock.chat")
            dockKey("✦", disabled: noteVM?.aiBusy == true) { Haptics.press(); noteVM?.requestOptimize(doc) }
                .accessibilityIdentifier("dock.optimize")
            dockIcon("trash", accent: false, disabled: false) {
                deleteNote(doc)
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

    private func deleteNote(_ doc: NoteDocument) {
        Haptics.warning()
        try? root.repository?.deleteNote(id: doc.noteID)
        root.toast.show(String(localized: "已刪除筆記"))
        dismiss()
    }
}

#Preview("P2 筆記頁") {
    NavigationStack {
        NoteDetailScreen(noteID: UUID())
    }
    .environment(CompositionRoot())
    .environment(\.palette, .matteBlack)
}
