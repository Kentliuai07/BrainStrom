import SwiftUI

// ============================================================
// 系統結構 · 身份證（階段三 第 2 刀）—— 只讀展示頁
// 鐵律：人只能看，不能直接改。寫入唯一通道＝AI 的 update_spec 提議經使用者點確認。
// 字段對齊 docs/系统身份证-设计文档.md：名稱／前端／後端／API／資料庫／伺服器／部署方式。
// ============================================================

struct SystemStructureView: View {

    let spec: SystemSpec

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if spec.isEmpty {
                    emptyState
                } else {
                    rows
                }
                footnote
            }
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.top, Tokens.Spacing.s4)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
    }

    // MARK: - 標頭

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: "🪪").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "系統身份證"))
                    .font(Tokens.Fonts.display(20, weight: .heavy))
                    .foregroundStyle(palette.print)
                Text(String(localized: "專案硬規格 · 由 AI 維護"))
                    .font(Tokens.Fonts.body(11.5))
                    .foregroundStyle(palette.print3)
            }
            Spacer()
        }
    }

    // MARK: - 欄位列

    private var rows: some View {
        VStack(spacing: 0) {
            specRow(icon: "tag", label: String(localized: "名稱"), value: spec.name)
            specRow(icon: "macwindow", label: String(localized: "前端"), value: spec.frontend)
            specRow(icon: "server.rack", label: String(localized: "後端"), value: spec.backend)
            specRow(icon: "point.3.connected.trianglepath.dotted",
                    label: String(localized: "API"),
                    value: spec.apis.isEmpty ? nil : spec.apis.joined(separator: "、"))
            specRow(icon: "cylinder.split.1x2", label: String(localized: "資料庫"), value: spec.database)
            specRow(icon: "externaldrive.connected.to.line.below", label: String(localized: "伺服器"), value: spec.server)
            specRow(icon: "arrow.up.forward.app", label: String(localized: "部署方式"), value: spec.deployMethod, last: true)
        }
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .fill(palette.panel)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).strokeBorder(palette.line, lineWidth: 1))
        )
    }

    private func specRow(icon: String, label: String, value: String?, last: Bool = false) -> some View {
        let filled = !((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(filled ? palette.orange : palette.print3)
                    .frame(width: 20)
                Text(label)
                    .font(Tokens.Fonts.body(13, weight: .semibold))
                    .foregroundStyle(palette.print2)
                    .frame(width: 64, alignment: .leading)
                if filled {
                    Text(value ?? "")
                        .font(Tokens.Fonts.body(13.5))
                        .foregroundStyle(palette.print)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(String(localized: "— 尚未填寫，讓 AI 記錄"))
                        .font(Tokens.Fonts.body(12.5))
                        .foregroundStyle(palette.print3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            if !last { Rectangle().fill(palette.line).frame(height: 1).padding(.leading, 44) }
        }
    }

    // MARK: - 空態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(verbatim: "🪪").font(.system(size: 34)).opacity(0.5)
            Text(String(localized: "身份證還是空白的"))
                .font(Tokens.Fonts.body(14, weight: .semibold))
                .foregroundStyle(palette.print2)
            Text(String(localized: "去「AI 教練」或「開發筆記」聊到技術棧、資料庫、上線方式，AI 會跳出「記入結構」鈕，點了就填進來。"))
                .font(Tokens.Fonts.body(12.5))
                .foregroundStyle(palette.print3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - 腳註（鐵律說明）

    private var footnote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield").font(.system(size: 11)).foregroundStyle(palette.print3)
            Text(String(localized: "這頁不能手動改，全部交給 AI 把關，確保規格乾淨可信。"))
                .font(Tokens.Fonts.mono(10))
                .foregroundStyle(palette.print3)
        }
        .padding(.top, 4)
    }
}

#Preview("系統結構 · 已填") {
    SystemStructureView(spec: SystemSpec(
        name: "BrainStrom", frontend: "SwiftUI", backend: "Node (Fly.io)",
        apis: ["Anthropic", "GitHub"], database: "SwiftData", server: "Fly.io", deployMethod: "fly deploy"))
        .environment(\.palette, .matteBlack)
}

#Preview("系統結構 · 空白") {
    SystemStructureView(spec: SystemSpec())
        .environment(\.palette, .matteBlack)
}
