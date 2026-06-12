import SwiftUI

// ============================================================
// 系統結構（階段三）—— 身份證 + 結構卡片（「卡片就是身份證」）
// 使用者裁定：結構卡片屬系統層級，不放在單篇筆記裡。
// 本頁＝專案的結構呈現：① 身份證硬規格（AI update_spec 維護）② 結構卡片（▦ 結構化產出）
// 卡片操作的是「專案主文件筆記」(documentNote)；筆記內頁只負責純寫作。
// ============================================================

struct SystemStructureView: View {

    let systemID: UUID
    /// 此分頁是否在前台（切過來時重讀，反映剛在筆記/教練記入的內容）。
    let active: Bool

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var doc: NoteDocument?
    @State private var vm: NoteViewModel?
    @State private var spec = SystemSpec()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                idCardSection
                Rectangle().fill(palette.line).frame(height: 1)
                cardsSection
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.top, Tokens.Spacing.s4)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .onAppear(perform: load)
        .onChange(of: active) { _, now in if now { load() } }
    }

    // MARK: - ① 身份證（5 區，AI update_spec 維護）

    private var idCardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(verbatim: "🪪").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "系統身份證"))
                        .font(Tokens.Fonts.display(19, weight: .heavy)).foregroundStyle(palette.print)
                    Text(String(localized: "理念＋技術 · 由 AI 維護，人只能看"))
                        .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
                }
                Spacer()
                Text(String(format: String(localized: "核心 %d/4"), spec.coreFilledCount))
                    .font(Tokens.Fonts.mono(11, weight: .bold))
                    .foregroundStyle(spec.coreComplete ? palette.orangeInk : palette.print2)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(spec.coreComplete ? palette.ledGreen.opacity(0.3) : palette.orangeDim))
            }
            if spec.isEmpty {
                Text(String(localized: "去「AI 教練」按⚡開始引導，AI 會一題一題出選項帶你把專案想清楚；點選項就填進這裡。"))
                    .font(Tokens.Fonts.body(12.5)).foregroundStyle(palette.print3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .fill(palette.panel).overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                            .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))))
            } else {
                zone(String(localized: "① 這是什麼"), [
                    (String(localized: "一句話"), spec.oneLiner, true), (String(localized: "目標用戶"), spec.targetUser, true)])
                zone(String(localized: "② 為什麼做"), [
                    (String(localized: "解決痛點"), spec.painPoint, true), (String(localized: "核心價值"), spec.coreValue, false)])
                zone(String(localized: "③ 市場"), [
                    (String(localized: "市場策略"), spec.marketStrategy, false), (String(localized: "商業模式"), spec.businessModel, false)])
                if !spec.competitors.isEmpty { competitorRows }
                zone(String(localized: "④ 先做什麼"), [(String(localized: "核心功能"), spec.coreFeatures, true)])
                zone(String(localized: "⑤ 技術"), [
                    (String(localized: "名稱"), spec.name, false), (String(localized: "前端"), spec.frontend, false),
                    (String(localized: "後端"), spec.backend, false),
                    (String(localized: "API"), spec.apis.isEmpty ? nil : spec.apis.joined(separator: "、"), false),
                    (String(localized: "資料庫"), spec.database, false), (String(localized: "伺服器"), spec.server, false),
                    (String(localized: "部署"), spec.deployMethod, false)])
            }
        }
    }

    /// 一個區塊：小標題 + 多行字段（rows: (標籤, 值, 是否核心⭐)）。
    private func zone(_ title: String, _ rows: [(String, String?, Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Tokens.Fonts.mono(10, weight: .bold)).kerning(1).foregroundStyle(palette.print3)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    specRow(label: r.0, value: r.1, core: r.2, last: i == rows.count - 1)
                }
            }
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(palette.panel)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).strokeBorder(palette.line, lineWidth: 1)))
        }
    }

    private func specRow(label: String, value: String?, core: Bool, last: Bool) -> some View {
        let filled = !((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 2) {
                    if core { Text(verbatim: "⭐").font(.system(size: 8)) }
                    Text(label).font(Tokens.Fonts.body(13, weight: .semibold)).foregroundStyle(palette.print2)
                }.frame(width: 76, alignment: .leading)
                Text(filled ? (value ?? "") : String(localized: "— 尚未填，讓 AI 記錄"))
                    .font(Tokens.Fonts.body(filled ? 13.5 : 12.5))
                    .foregroundStyle(filled ? palette.print : palette.print3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            if !last { Rectangle().fill(palette.line).frame(height: 1).padding(.leading, 14) }
        }
    }

    /// 競品列（記入身份證的真實 App/repo）。
    private var competitorRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "競品")).font(Tokens.Fonts.mono(10, weight: .bold)).kerning(1).foregroundStyle(palette.print3)
            ForEach(Array(spec.competitors.enumerated()), id: \.offset) { _, c in
                HStack(spacing: 8) {
                    Text(verbatim: c.source == "github" ? "🐙" : "").font(.system(size: 13))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.title).font(Tokens.Fonts.body(13, weight: .semibold)).foregroundStyle(palette.print).lineLimit(1)
                        if let s = c.subtitle, !s.isEmpty {
                            Text(s).font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3).lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(palette.panel)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.line, lineWidth: 1)))
            }
        }
    }

    // MARK: - ② 結構卡片（▦ 結構化產出；操作主文件筆記）

    @ViewBuilder
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: "▦").font(.system(size: 16, weight: .bold)).foregroundStyle(palette.orange)
                Text(String(localized: "結構卡片"))
                    .font(Tokens.Fonts.display(18, weight: .heavy)).foregroundStyle(palette.print)
                Spacer()
            }
            if let doc {
                CardsView(doc: doc, runStructure: { vm?.runStructure(doc) }, vm: vm)
            } else {
                Text(String(localized: "這個專案還沒有可結構化的筆記內容。先去「開發筆記」寫點東西。"))
                    .font(Tokens.Fonts.body(12.5)).foregroundStyle(palette.print3)
                    .padding(.vertical, 20)
            }
        }
        .overlay(alignment: .top) {
            if vm?.aiBusy == true {
                ProgressView().tint(palette.orange).padding(.top, 2)
            }
        }
    }

    // MARK: - 載入（主文件筆記 + 身份證）

    private func load() {
        guard let repo = root.repository else { return }
        spec = (try? repo.systemSpec(systemID: systemID)) ?? SystemSpec()
        if let note = try? repo.documentNote(for: systemID) {
            doc = NoteDocument(noteID: note.id, repository: repo)
        }
        if vm == nil { vm = NoteViewModel(ai: root.ai, toast: root.toast) }
    }
}

#Preview("系統結構") {
    SystemStructureView(systemID: UUID(), active: true)
        .environment(CompositionRoot())
        .environment(\.palette, .matteBlack)
}
