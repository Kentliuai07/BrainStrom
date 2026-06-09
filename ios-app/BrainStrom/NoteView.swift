// NoteView.swift — Apple Notes 风格的笔记页（文档式 + 内嵌模组）
import SwiftUI

struct NoteView: View {
    @State var note: Note = .sample
    @State private var showAddModule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 居中日期（Apple Notes 习惯）
                    Text(note.date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)

                    // 大标题
                    Text(note.title)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .tracking(-0.5)
                        .padding(.top, 8)

                    // 正文块流
                    ForEach(note.blocks) { block in
                        blockView(block).padding(.top, blockSpacing(block))
                    }

                    // 当前光标行
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.notesYellow)
                            .frame(width: 2, height: 20)
                    }
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 22)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // Apple Notes 风格底部工具栏
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showAddModule) {
                AddModuleSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .tint(Theme.folderTint)
    }

    // MARK: 块渲染
    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .paragraph(_, let text):
            Text(text).font(.system(size: 16)).foregroundStyle(Theme.body).lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .heading(_, let text):
            Text(text).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .todo(_, let items):
            TodoModule(items: items)
        case .mindMap(_, let title):
            MindMapModule(title: title)
        case .github(_, let repo, let desc, _):
            GitHubModule(repo: repo, desc: desc)
        case .video(_, let title, let duration):
            VideoModule(title: title, duration: duration)
        }
    }

    private func blockSpacing(_ block: Block) -> CGFloat {
        switch block {
        case .heading: return 20
        case .mindMap, .github, .video: return 14
        default: return 12
        }
    }

    // MARK: 顶部导航
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {} label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text(note.folder).font(.system(size: 17))
                }
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {} label: { Image(systemName: "square.and.arrow.up") }
            Button {} label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: 底部工具栏（中间渐变＋号 = 加模组）
    private var bottomBar: some View {
        HStack {
            toolButton("textformat")
            Spacer()
            toolButton("checklist")
            Spacer()
            toolButton("tablecells")
            Spacer()
            Button { showAddModule = true } label: {
                ZStack {
                    Circle().fill(Theme.brand)
                        .shadow(color: Color(hex: 0xD946EF).opacity(0.35), radius: 8, y: 3)
                    Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
            }
            Spacer()
            toolButton("photo")
            Spacer()
            Button {} label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles"); Text("AI").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0x5B4FE8))
            }
        }
        .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func toolButton(_ symbol: String) -> some View {
        Button {} label: {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Theme.body)
        }
    }
}

/// 内嵌影片模组
struct VideoModule: View {
    var title: String, duration: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: [Color(hex: 0xFBCFE8), Color(hex: 0xC7D2FE)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 150)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 46)).foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(duration).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: Capsule()).padding(10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label("灵感来源 · 影片", systemImage: "link").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            .padding(14)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .embedShadow()
    }
}

#Preview {
    NoteView()
}
