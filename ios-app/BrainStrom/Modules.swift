// Modules.swift — 各种内嵌模组的视图
import SwiftUI

/// 内嵌「心智图」模组：原生绘制的流程分支
struct MindMapModule: View {
    var title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.catFlow)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.secondary)
                Spacer()
                Image(systemName: "line.3.horizontal").font(.system(size: 11)).foregroundStyle(Color(hex: 0xC7C7CC))
            }
            HStack(spacing: 10) {
                node("用户一句话", filled: false)
                arrow
                node("AI 拆字段", filled: true)
                arrow
                VStack(spacing: 8) {
                    node("地图 API", filled: false, small: true)
                    node("天气 API", filled: false, small: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black.opacity(0.06)))
        .embedShadow()
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.catFlow.opacity(0.5))
    }
    private func node(_ t: String, filled: Bool, small: Bool = false) -> some View {
        Text(t)
            .font(.system(size: small ? 11 : 12, weight: filled ? .semibold : .regular))
            .foregroundStyle(filled ? .white : Color(hex: 0x0369A1))
            .padding(.horizontal, 10).padding(.vertical, small ? 6 : 9)
            .background(filled ? Theme.catFlow : Color(hex: 0xE0F2FE),
                        in: Capsule())
    }
}

/// 内嵌「GitHub 项目」模组（Notion bookmark 风格）
struct GitHubModule: View {
    var repo: String, desc: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(desc).font(.system(size: 12.5)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(hex: 0xC7C7CC))
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black.opacity(0.06)))
        .embedShadow()
    }
}

/// 待办清单块（Apple Notes 黄色勾选圈）
struct TodoModule: View {
    @State var items: [TodoItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($items) { $item in
                Button {
                    item.done.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            if item.done {
                                Circle().fill(Theme.notesYellow)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Circle().stroke(Color(hex: 0xD1D1D6), lineWidth: 1.8)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(item.text)
                            .font(.system(size: 16))
                            .foregroundStyle(item.done ? Theme.secondary : Theme.body)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
