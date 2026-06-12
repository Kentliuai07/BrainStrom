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

    // MARK: - ① 身份證（硬規格，AI update_spec 維護）

    private var idCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: "🪪").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "系統身份證"))
                        .font(Tokens.Fonts.display(19, weight: .heavy)).foregroundStyle(palette.print)
                    Text(String(localized: "硬規格 · 由 AI 維護，人只能看"))
                        .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
                }
                Spacer()
            }
            if spec.isEmpty {
                Text(String(localized: "去「AI 教練」或「開發筆記」聊到技術棧、資料庫、上線方式，AI 會跳「記入結構」鈕，點了就填進來。"))
                    .font(Tokens.Fonts.body(12.5)).foregroundStyle(palette.print3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .fill(palette.panel).overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card)
                            .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))))
            } else {
                specRows
            }
        }
    }

    private var specRows: some View {
        VStack(spacing: 0) {
            specRow(icon: "tag", label: String(localized: "名稱"), value: spec.name)
            specRow(icon: "macwindow", label: String(localized: "前端"), value: spec.frontend)
            specRow(icon: "server.rack", label: String(localized: "後端"), value: spec.backend)
            specRow(icon: "point.3.connected.trianglepath.dotted", label: String(localized: "API"),
                    value: spec.apis.isEmpty ? nil : spec.apis.joined(separator: "、"))
            specRow(icon: "cylinder.split.1x2", label: String(localized: "資料庫"), value: spec.database)
            specRow(icon: "externaldrive.connected.to.line.below", label: String(localized: "伺服器"), value: spec.server)
            specRow(icon: "arrow.up.forward.app", label: String(localized: "部署方式"), value: spec.deployMethod, last: true)
        }
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(palette.panel)
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).strokeBorder(palette.line, lineWidth: 1)))
    }

    private func specRow(icon: String, label: String, value: String?, last: Bool = false) -> some View {
        let filled = !((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(filled ? palette.orange : palette.print3).frame(width: 20)
                Text(label).font(Tokens.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(palette.print2).frame(width: 64, alignment: .leading)
                Text(filled ? (value ?? "") : String(localized: "— 尚未填寫，讓 AI 記錄"))
                    .font(Tokens.Fonts.body(filled ? 13.5 : 12.5))
                    .foregroundStyle(filled ? palette.print : palette.print3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            if !last { Rectangle().fill(palette.line).frame(height: 1).padding(.leading, 44) }
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
