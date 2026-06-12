import SwiftUI

// ============================================================
// P2-容器 · 專案首頁（階段三 · 結構大修 第 1 刀骨架）
// 頂部三分頁：🤖 AI 教練 / 📝 開發筆記 / 🪪 系統結構
// 第 1 刀只搭骨架：教練/結構先放占位，開發筆記直接塞「目前單筆」(NoteScreen)。
// 關鍵：三頁同時掛載（ZStack 切顯隱），NoteScreen 不隨切頁卸載——
// 避免 cleanupEmptyOnLeave 在切頁時誤刪整個系統（洞3 回歸點，正式拆分留第 3 刀）。
// ============================================================

struct SystemDetailScreen: View {

    let systemID: UUID
    @Binding var path: NavigationPath

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var systemSpec = SystemSpec()

    enum Tab: String, CaseIterable {
        case coach, notes, structure
        var label: String {
            switch self {
            case .coach: String(localized: "AI 教練")
            case .notes: String(localized: "開發筆記")
            case .structure: String(localized: "系統結構")
            }
        }
        var glyph: String {
            switch self {
            case .coach: "🤖"
            case .notes: "📝"
            case .structure: "🪪"
            }
        }
    }

    @State private var tab: Tab = .notes

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ZStack {
                AICoachView(systemID: systemID)
                    .opacity(tab == .coach ? 1 : 0)
                    .allowsHitTesting(tab == .coach)

                NotesListView(systemID: systemID, path: $path)
                    .opacity(tab == .notes ? 1 : 0)
                    .allowsHitTesting(tab == .notes)

                SystemStructureView(spec: systemSpec)
                    .opacity(tab == .structure ? 1 : 0)
                    .allowsHitTesting(tab == .structure)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.bg)
        .navigationBarHidden(true)
        .onAppear(perform: reloadSpec)
        .onChange(of: tab) { _, new in
            if new == .structure { reloadSpec() }   // 切到結構頁時重讀（筆記/教練可能剛記入）
        }
    }

    /// 從倉儲重讀身份證（update_spec 寫入後切回此頁即可見最新）。
    private func reloadSpec() {
        guard let repo = root.repository else { return }
        systemSpec = (try? repo.systemSpec(systemID: systemID)) ?? SystemSpec()
    }

    // MARK: - 三分頁切換條（沿用工業風 segButton 樣式）

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                tabButton(t)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(palette.recess)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.line, lineWidth: 1))
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(palette.panel.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    private func tabButton(_ t: Tab) -> some View {
        let on = tab == t
        return Button {
            Haptics.tap()
            tab = t
        } label: {
            HStack(spacing: 5) {
                Text(verbatim: t.glyph).font(.system(size: 13))
                Text(t.label)
                    .font(Tokens.Fonts.body(12.5, weight: .bold))
            }
            .foregroundStyle(on ? palette.orangeInk : palette.print2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(on ? palette.orange : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("systemDetail.tab.\(t.rawValue)")
    }

}

#Preview("P2 專案首頁(三分頁)") {
    NavigationStack {
        SystemDetailScreen(systemID: UUID(), path: .constant(NavigationPath()))
    }
    .environment(CompositionRoot())
    .environment(\.palette, .matteBlack)
}
