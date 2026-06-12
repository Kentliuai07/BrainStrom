import SwiftUI

// ============================================================
// 筆記頁內容視圖 —— 文章視圖（標題 + 塊 + 續寫）／卡片視圖
// 佈局對齊 web renderArticle()/renderCards()；工業橘皮。
// ============================================================

// MARK: - 文章視圖

struct ArticleView: View {

    @Bindable var doc: NoteDocument

    @Environment(\.palette) private var palette
    @State private var titleText = ""
    @State private var continueText = ""
    @FocusState private var titleFocused: Bool
    @FocusState private var continueFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題（階段三 v3：純改標題，無命名閘）
            TextField(text: $titleText, axis: .vertical) {
                Text(String(localized: "標題"))
            }
            .font(Tokens.Fonts.body(24, weight: .heavy))
            .foregroundStyle(palette.print)
            .focused($titleFocused)
            .accessibilityIdentifier("note.title")
            .onAppear { titleText = doc.title }
            .onChange(of: titleFocused) { _, focused in
                if !focused { doc.commitTitle(titleText); titleText = doc.title }
            }

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

            // 文末續寫（web .note-body）：失焦才提交、splitIntoBlocks 切塊（與網頁一致）
            TextField(text: $continueText, axis: .vertical) {
                Text(String(localized: "繼續寫…（空行分段、# 開頭成標題）"))
            }
            .font(Tokens.Fonts.body(15))
            .foregroundStyle(palette.print)
            .lineSpacing(4)
            .padding(.top, 10)
            .focused($continueFocused)
            .accessibilityIdentifier("note.continue")
            .onChange(of: continueFocused) { _, focused in
                if !focused, !continueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    doc.appendFromContinue(continueText)
                    continueText = ""
                }
            }
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
            VStack(alignment: .leading, spacing: 2) {
                if focused && text.count > 2000 {
                    Text(String(localized: "⚠ 這段超過 2000 字，建議拆分"))
                        .font(Tokens.Fonts.mono(10, weight: .semibold))
                        .foregroundStyle(palette.danger)
                }
                TextField(text: $text, axis: .vertical) {
                    Text(block.kind == .todo ? String(localized: "待辦…") : String(localized: "寫點什麼…"))
                }
                .font(font(for: block.kind))
                .foregroundStyle(palette.print)
                .strikethrough(block.kind == .todo && block.isDone, color: palette.print3)
                .focused($focused)
            }
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
                // 🔒 智能排除：鎖上 = AI 看不到這塊（階段三）
                Button { doc.toggleExcluded(block.id) } label: {
                    Image(systemName: block.excludedFromAI ? "lock.fill" : "lock.open")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(block.excludedFromAI ? palette.orange : palette.print3)
                        .frame(width: 22, height: 16)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("block.lock")
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
    var vm: NoteViewModel?

    @Environment(\.palette) private var palette

    var body: some View {
        if let vm, vm.structuring {
            VStack(spacing: 11) {
                ForEach(vm.streamingCards) { card in streamingCard(card) }
            }
        } else if !doc.docStateIsCarded {
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
                .accessibilityIdentifier("structure.run")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        } else {
            VStack(spacing: 11) {
                ForEach(doc.orderedBlocks) { block in
                    CardRow(doc: doc, block: block)
                }
            }
        }
    }

    private func streamingCard(_ card: NoteViewModel.StreamingCard) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !card.title.isEmpty {
                Text(card.title).font(Tokens.Fonts.body(14, weight: .bold)).foregroundStyle(palette.print)
            }
            if let content = card.content {
                MarkdownView(blocks: MarkdownParser.parse(content))
            } else {
                RoundedRectangle(cornerRadius: 6).fill(palette.panel2).frame(height: 28)   // 骨架占位
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .hardwareCard()
        .overlay {
            NotchedRectangle(notch: Tokens.Notch.card)
                .strokeBorder(palette.orange.opacity(card.content == nil ? 0.5 : 0.2), lineWidth: 1)
        }
    }
}

/// 卡片視圖的一張板卡（web .aicard；釘選/刪除工具、模組卡、就地編輯）。
struct CardRow: View {
    @Bindable var doc: NoteDocument
    let block: Block
    @Environment(\.palette) private var palette
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isTextual: Bool {
        block.kind == .paragraph || block.kind == .heading1 || block.kind == .heading2
    }

    var body: some View {
        Group {
            if block.kind == .module { moduleCard } else { textCard }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .hardwareCard()
        .overlay(alignment: .topTrailing) { tools }
        .overlay {
            if block.isPinned {
                NotchedRectangle(notch: Tokens.Notch.card)
                    .strokeBorder(palette.orange.opacity(0.4), lineWidth: 1.5)
            }
        }
    }

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            let title = block.cardTitle ?? (block.kind == .heading1 || block.kind == .heading2 ? block.text : nil)
            if let title, !title.isEmpty {
                HStack(spacing: 4) {
                    if block.isPinned { Text(verbatim: "📌").font(.system(size: 11)) }
                    Text(title).font(Tokens.Fonts.body(14, weight: .bold)).foregroundStyle(palette.print)
                }
            }
            if editing {
                TextField(text: $text, axis: .vertical) { Text(verbatim: "") }
                    .font(Tokens.Fonts.body(13.5))
                    .foregroundStyle(palette.print)
                    .focused($focused)
                    .onChange(of: focused) { _, f in
                        if !f { doc.editBlockText(block.id, to: text); editing = false }
                    }
            } else if block.text.isEmpty {
                Text(String(localized: "（空白，點擊編輯）"))
                    .font(Tokens.Fonts.body(13.5))
                    .foregroundStyle(palette.print3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { text = block.text; editing = true; focused = true }
            } else {
                // 顯示態：markdown 排版；點一下進編輯（編輯時看原文）
                MarkdownView(blocks: MarkdownParser.parse(block.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { text = block.text; editing = true; focused = true }
            }
        }
        .padding(.trailing, 44)
    }

    private var moduleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "📌 \(String(localized: "模組")) · \(block.moduleKind?.rawValue ?? "module")")
                .font(Tokens.Fonts.mono(11, weight: .bold)).foregroundStyle(palette.print2)
            Text(block.modulePayload ?? "{}")
                .font(Tokens.Fonts.mono(11)).foregroundStyle(palette.print3).lineLimit(2)
        }
        .padding(.trailing, 44)
    }

    private var tools: some View {
        HStack(spacing: 2) {
            if isTextual {
                Button { doc.togglePin(block.id) } label: {
                    Text(verbatim: "📌").font(.system(size: 11))
                        .opacity(block.isPinned ? 1 : 0.4).grayscale(block.isPinned ? 0 : 1)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
            }
            Button { doc.delete(block.id) } label: {
                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(palette.print3)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }
}
