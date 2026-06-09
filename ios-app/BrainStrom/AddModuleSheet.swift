// AddModuleSheet.swift — Notion 风格的「加模组」面板（块都是氛围开发专用）
import SwiftUI

struct AddModuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    struct ModuleRow: Identifiable {
        let id = UUID()
        let symbol: String
        let symbolColor: Color
        let bg: Color
        let title: String
        let desc: String
        var badge: String? = nil
        var dark: Bool = false
        var gradient: Bool = false
    }

    private let vibeModules: [ModuleRow] = [
        .init(symbol: "brain", symbolColor: Theme.catFlow, bg: Color(hex: 0xE0F2FE),
              title: "心智图", desc: "把流程 / 想法画成节点图", badge: "AI 可生成"),
        .init(symbol: "play.rectangle.fill", symbolColor: Theme.catLook, bg: Color(hex: 0xFFE4E6),
              title: "影片", desc: "嵌 YouTube / B站 参考"),
        .init(symbol: "chevron.left.forwardslash.chevron.right", symbolColor: .white, bg: Theme.ink,
              title: "GitHub 项目", desc: "收藏要用的开源仓库", dark: true),
        .init(symbol: "curlybraces", symbolColor: Theme.catTool, bg: Color(hex: 0xEDE9FE),
              title: "代码片段", desc: "贴一段 prompt 或代码"),
        .init(symbol: "sparkles", symbolColor: .white, bg: .clear,
              title: "AI 分析模组", desc: "市场潜力 / 查缺补漏", gradient: true),
    ]
    private let basicModules: [ModuleRow] = [
        .init(symbol: "checklist", symbolColor: Color(hex: 0xB5860B), bg: Color(hex: 0xFEF3C7),
              title: "待办清单", desc: "可勾选的步骤"),
        .init(symbol: "textformat.size", symbolColor: Color(hex: 0x475569), bg: Color(hex: 0xF1F5F9),
              title: "标题", desc: "给段落分节"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("加模组").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24)).foregroundStyle(Color(hex: 0xC7C7CC))
                }
            }
            .padding(.horizontal, 20).padding(.top, 14)

            // 搜索
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                TextField("搜模组，或直接打字…", text: $query)
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20).padding(.top, 12)

            ScrollView {
                section("氛围开发模组", rows: vibeModules, highlightFirst: true)
                section("基础块", rows: basicModules, highlightFirst: false)
                    .padding(.top, 18)
                Spacer(minLength: 24)
            }
            .padding(.top, 14)
        }
        .background(Color(hex: 0xF7F7F4).ignoresSafeArea())
    }

    private func section(_ title: String, rows: [ModuleRow], highlightFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.secondary)
                .padding(.horizontal, 22).padding(.bottom, 6)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    moduleRow(row, highlighted: highlightFirst && idx == 0)
                    if idx < rows.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black.opacity(0.05)))
            .padding(.horizontal, 16)
        }
    }

    private func moduleRow(_ row: ModuleRow, highlighted: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if row.gradient {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.brand)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(row.bg)
                }
                Image(systemName: row.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(row.symbolColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(row.desc).font(.system(size: 12.5)).foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 4)
            if let badge = row.badge {
                Text(badge).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x6366F1))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(highlighted ? Color(hex: 0x6366F1, alpha: 0.08) : .clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    Text("背景").sheet(isPresented: .constant(true)) {
        AddModuleSheet()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}
