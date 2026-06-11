import SwiftUI

// ============================================================
// 筆記頁內容視圖 —— 文章視圖（標題 + 塊 + 續寫）／卡片視圖
// 佈局對齊 web renderArticle()/renderCards()；工業橘皮。
// ============================================================

// MARK: - 文章視圖

struct ArticleView: View {

    @Bindable var doc: NoteDocument
    @Binding var continueText: String

    @Environment(\.palette) private var palette
    @Environment(CompositionRoot.self) private var root
    @State private var titleText = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題（web .note-title）
            TextField(text: $titleText, axis: .vertical) {
                Text(doc.naming ? String(localized: "先給這個點子取個名字") : String(localized: "標題"))
            }
            .font(Tokens.Fonts.body(24, weight: .heavy))
            .foregroundStyle(palette.print)
            .focused($titleFocused)
            .onAppear { titleText = doc.title }
            .onChange(of: titleFocused) { _, focused in
                if !focused { doc.commitTitle(titleText); titleText = doc.title }
            }

            // titleaux：命名態放「先隨便取」；命名後放 ⚡ 助攻膠囊
            titleAux
                .padding(.top, 6)

            if doc.naming {
                // 命名態（web .naminghint）
                Text(String(localized: "✏️ 先給這個點子取個名字，就能開始寫"))
                    .font(Tokens.Fonts.body(14))
                    .foregroundStyle(palette.print3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18).padding(.horizontal, 14)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    .padding(.top, 18)
            } else {
                // 塊串（web .blocks）
                VStack(alignment: .leading, spacing: 8) {
                    if doc.orderedBlocks.isEmpty {
                        Text(String(localized: "空白筆記——直接在下方「繼續寫…」開始，或 ＋ 加模組"))
                            .font(Tokens.Fonts.body(13))
                            .foregroundStyle(palette.print3)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                    }
                    ForEach(doc.orderedBlocks) { block in
                        BlockRow(doc: doc, block: block)
                    }
                }
                .padding(.top, 14)

                // 文末續寫（web .note-body）
                TextField(text: $continueText, axis: .vertical) {
                    Text(String(localized: "繼續寫…（空行分段、# 開頭成標題）"))
                }
                .font(Tokens.Fonts.body(15))
                .foregroundStyle(palette.print)
                .lineSpacing(4)
                .padding(.top, 10)
                .submitLabel(.return)
                .onChange(of: continueText) { _, new in
                    // 連按兩次換行＝提交一段（近似 web blur 提交）
                    if new.hasSuffix("\n\n") {
                        doc.appendFromContinue(new)
                        continueText = ""
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var titleAux: some View {
        if doc.naming {
            Button {
                _ = doc.quickName(); titleText = doc.title
            } label: {
                Text(String(localized: "先隨便取"))
                    .font(Tokens.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(palette.print3)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().strokeBorder(palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else if !doc.title.isEmpty {
            // ⚡ 助攻膠囊（佈局；點擊先提示需後端）
            Button {
                root.toast.show(String(localized: "此功能需要真後端（尚未整合）"))
            } label: {
                Text(String(localized: "⚡ 讓 AI 教練看看這個點子"))
                    .font(Tokens.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(palette.orange)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(palette.orangeDim)
                        .overlay(Capsule().strokeBorder(palette.orange.opacity(0.3), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 單一塊（可編輯 + 工具列）

struct BlockRow: View {

    @Bindable var doc: NoteDocument
    let block: Block

    @Environment(\.palette) private var palette
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if block.kind == .todo {
                Button { doc.toggleTodo(block.id) } label: {
                    ZStack {
                        Circle().strokeBorder(block.isDone ? palette.orange : palette.print3, lineWidth: 2)
                        if block.isDone {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(palette.orange)
                        }
                    }
                    .frame(width: 20, height: 20).padding(.top, 3)
                }
                .buttonStyle(.plain)
            } else if block.isPinned {
                Rectangle().fill(palette.orange).frame(width: 2).padding(.vertical, 2)
            }

            editor

            Spacer(minLength: 0)
            tools
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(block.isPinned ? palette.panel : .clear)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(block.isPinned ? palette.orange.opacity(0.3) : .clear, lineWidth: 1))
        )
        .onAppear { text = block.text }
        .onChange(of: focused) { _, f in
            if !f && (block.kind == .todo || isTextual) { doc.editBlockText(block.id, to: text) }
        }
    }

    private var isTextual: Bool {
        block.kind == .paragraph || block.kind == .heading1 || block.kind == .heading2
    }

    @ViewBuilder
    private var editor: some View {
        if block.kind == .module {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "📌 \(String(localized: "模組")) · \(block.moduleKind?.rawValue ?? "module")")
                    .font(Tokens.Fonts.mono(11, weight: .bold))
                    .foregroundStyle(palette.print2)
                Text(block.modulePayload ?? "{}")
                    .font(Tokens.Fonts.mono(11))
                    .foregroundStyle(palette.print3)
                    .lineLimit(2)
            }
        } else {
            TextField(text: $text, axis: .vertical) {
                Text(block.kind == .todo ? String(localized: "待辦…") : String(localized: "寫點什麼…"))
            }
            .font(font(for: block.kind))
            .foregroundStyle(palette.print)
            .strikethrough(block.kind == .todo && block.isDone, color: palette.print3)
            .focused($focused)
        }
    }

    private var tools: some View {
        VStack(spacing: 0) {
            if isTextual {
                Button { doc.togglePin(block.id) } label: {
                    Text(verbatim: "📌").font(.system(size: 11))
                        .opacity(block.isPinned ? 1 : 0.4).grayscale(block.isPinned ? 0 : 1)
                        .frame(width: 22, height: 18)
                }.buttonStyle(.plain)
            }
            Button { doc.move(block.id, by: -1) } label: {
                Image(systemName: "chevron.up").font(.system(size: 9)).foregroundStyle(palette.print3).frame(width: 22, height: 14)
            }.buttonStyle(.plain)
            Button { doc.move(block.id, by: 1) } label: {
                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(palette.print3).frame(width: 22, height: 14)
            }.buttonStyle(.plain)
            Button { doc.delete(block.id) } label: {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(palette.print3).frame(width: 22, height: 18)
            }.buttonStyle(.plain)
        }
        .opacity(0.55)
    }

    private func font(for kind: BlockKind) -> Font {
        switch kind {
        case .heading1: Tokens.Fonts.body(18, weight: .heavy)
        case .heading2: Tokens.Fonts.body(16, weight: .bold)
        default: Tokens.Fonts.body(15)
        }
    }
}

// MARK: - 卡片視圖

struct CardsView: View {

    @Bindable var doc: NoteDocument
    let runStructure: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        if !doc.docStateIsCarded {
            VStack(spacing: 14) {
                Text(String(localized: "還沒結構化\n—— 按下面的按鈕，AI 會把筆記整理成一張張主題卡"))
                    .font(Tokens.Fonts.body(14))
                    .foregroundStyle(palette.print3)
                    .multilineTextAlignment(.center)
                Button {
                    Haptics.press(); runStructure()
                } label: {
                    Text(String(localized: "▦ 卡片結構化"))
                        .font(Tokens.Fonts.body(14.5, weight: .semibold))
                        .frame(width: 180, height: 46)
                }
                .buttonStyle(.keycap(.orange))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        } else {
            VStack(spacing: 11) {
                ForEach(doc.orderedBlocks) { block in
                    CardRow(block: block)
                }
            }
        }
    }
}

/// 卡片視圖的一張板卡（web .aicard）。
struct CardRow: View {
    let block: Block
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if block.kind == .heading1 || block.kind == .heading2 {
                Text(block.text)
                    .font(Tokens.Fonts.body(14, weight: .bold))
                    .foregroundStyle(palette.print)
            }
            Text(block.text.isEmpty ? String(localized: "（空白，點擊編輯）") : block.text)
                .font(Tokens.Fonts.body(13.5))
                .foregroundStyle(palette.print2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .hardwareCard()
    }
}
