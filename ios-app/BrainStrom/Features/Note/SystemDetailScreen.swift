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

    @Environment(\.palette) private var palette

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
                placeholder(
                    title: String(localized: "AI 教練"),
                    glyph: "🤖",
                    desc: String(localized: "陪你發想、幫你想清楚，看得到整個專案。階段三第 4 刀上線。"))
                    .opacity(tab == .coach ? 1 : 0)
                    .allowsHitTesting(tab == .coach)

                NoteScreen(systemID: systemID)
                    .opacity(tab == .notes ? 1 : 0)
                    .allowsHitTesting(tab == .notes)

                placeholder(
                    title: String(localized: "系統結構"),
                    glyph: "🪪",
                    desc: String(localized: "專案身份證：名稱／技術棧／資料庫／上線。只有 AI 能寫，你只能看。階段三第 2 刀上線。"))
                    .opacity(tab == .structure ? 1 : 0)
                    .allowsHitTesting(tab == .structure)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.bg)
        .navigationBarHidden(true)
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

    // MARK: - 占位頁（教練／結構）

    private func placeholder(title: String, glyph: String, desc: String) -> some View {
        VStack(spacing: 14) {
            Text(verbatim: glyph).font(.system(size: 40))
            Text(title)
                .font(Tokens.Fonts.display(20, weight: .heavy))
                .foregroundStyle(palette.print)
            Text(desc)
                .font(Tokens.Fonts.body(13))
                .foregroundStyle(palette.print2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            HStack(spacing: 5) {
                Text(verbatim: "🚧").font(.system(size: 11))
                Text(String(localized: "規劃中 · 階段三結構大修"))
                    .font(Tokens.Fonts.mono(10, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(palette.print3)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(palette.orangeDim)
                .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(palette.bg)
    }
}

#Preview("P2 專案首頁(三分頁)") {
    NavigationStack {
        SystemDetailScreen(systemID: UUID())
    }
    .environment(CompositionRoot())
    .environment(\.palette, .matteBlack)
}
