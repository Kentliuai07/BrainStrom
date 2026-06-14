import SwiftUI

// ============================================================
// 輕量 Markdown 渲染（零第三方依賴）—— 讓 AI 回應像 Claude.ai 排版
// 區塊級(標題/段落/清單/程式碼框/引用)自製解析；行內(粗體/斜體/碼/連結)
// 復用 Apple 的 AttributedString(markdown:)。工業橘美學。
// ============================================================

/// Markdown 區塊。
enum MarkdownBlock: Equatable {
    case heading(level: Int, String)
    case paragraph(String)
    case bullet([String])
    case ordered([String])
    case codeBlock(lang: String?, String)
    case quote([String])
}

/// 逐行掃描狀態機：把原文切成區塊。涵蓋 AI 輸出最常見 5 類；表格/巢狀清單 v2 再說。
enum MarkdownParser {

    static func parse(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var para: [String] = []
        var bullets: [String] = []
        var ordered: [String] = []
        var quote: [String] = []
        var inCode = false
        var codeLang: String?
        var code: [String] = []

        func flushPara() { if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: " "))); para = [] } }
        func flushBullets() { if !bullets.isEmpty { blocks.append(.bullet(bullets)); bullets = [] } }
        func flushOrdered() { if !ordered.isEmpty { blocks.append(.ordered(ordered)); ordered = [] } }
        func flushQuote() { if !quote.isEmpty { blocks.append(.quote(quote)); quote = [] } }
        func flushAll() { flushPara(); flushBullets(); flushOrdered(); flushQuote() }

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 程式碼框圍欄：框內原樣保留、不解析
            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.codeBlock(lang: codeLang, code.joined(separator: "\n")))
                    code = []; inCode = false; codeLang = nil
                } else {
                    flushAll()
                    inCode = true
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
                continue
            }
            if inCode { code.append(line); continue }

            if trimmed.isEmpty { flushAll(); continue }

            // 標題 # ~ ###（>3 級併入 3）
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                let rest = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if hashes <= 6, !rest.isEmpty {
                    flushAll(); blocks.append(.heading(level: min(hashes, 3), rest)); continue
                }
            }
            // 引用 >
            if trimmed.hasPrefix(">") {
                flushPara(); flushBullets(); flushOrdered()
                quote.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)); continue
            }
            // 無序清單 - * •
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flushPara(); flushOrdered(); flushQuote()
                bullets.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)); continue
            }
            // 有序清單 1.
            if let r = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                flushPara(); flushBullets(); flushQuote()
                ordered.append(String(trimmed[r.upperBound...])); continue
            }
            // 一般段落
            flushBullets(); flushOrdered(); flushQuote()
            para.append(trimmed)
        }
        if inCode { blocks.append(.codeBlock(lang: codeLang, code.joined(separator: "\n"))) }
        flushAll()
        return blocks
    }
}

/// 渲染區塊為 SwiftUI 視圖（工業橘樣式）。
struct MarkdownView: View {
    let blocks: [MarkdownBlock]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level == 1 ? Tokens.Fonts.display(20, weight: .heavy)
                      : level == 2 ? Tokens.Fonts.display(17, weight: .bold)
                      : Tokens.Fonts.body(15, weight: .bold))
                .foregroundStyle(level >= 3 ? palette.print2 : palette.print)
                .padding(.top, level == 1 ? 6 : 2)
                .overlay(alignment: .bottom) {
                    if level == 1 { Rectangle().fill(palette.orange.opacity(0.4)).frame(height: 1).offset(y: 4) }
                }

        case .paragraph(let text):
            inline(text).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print).lineSpacing(4)

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text(verbatim: "•").foregroundStyle(palette.orange)
                        inline(item).foregroundStyle(palette.print)
                    }
                    .font(Tokens.Fonts.body(13.5))
                }
            }
            .padding(.leading, 4)

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text(verbatim: "\(i + 1).").font(Tokens.Fonts.mono(12)).foregroundStyle(palette.orange)
                        inline(item).font(Tokens.Fonts.body(13.5)).foregroundStyle(palette.print)
                    }
                }
            }
            .padding(.leading, 4)

        case .codeBlock(let lang, let codeText):
            VStack(alignment: .leading, spacing: 4) {
                if let lang { Text(lang).font(Tokens.Fonts.mono(9)).foregroundStyle(palette.print3) }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(codeText).font(Tokens.Fonts.mono(12.5)).foregroundStyle(palette.print)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input)).fill(palette.recess))

        case .quote(let lines):
            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(palette.orange).frame(width: 2)
                inline(lines.joined(separator: " "))
                    .font(Tokens.Fonts.body(13.5)).italic().foregroundStyle(palette.print2)
                    .padding(.leading, 10).padding(.vertical, 2)
            }
            .background(RoundedRectangle(cornerRadius: palette.radius(8)).fill(palette.panel2))
        }
    }

    /// 行內 markdown（粗體/斜體/行內碼/連結）→ Text，復用 Apple AttributedString；失敗回純文字。
    private func inline(_ s: String) -> Text {
        guard var attr = try? AttributedString(
            markdown: s,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else { return Text(s) }
        for run in attr.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attr[run.range].font = .system(size: 12, design: .monospaced)
            attr[run.range].foregroundColor = palette.print2
        }
        return Text(attr)
    }
}

#Preview("Markdown") {
    let md = """
    # 研究計畫
    這是 **重點** 段落，含 `inline code` 與 *斜體*。

    ## 步驟
    - 第一點
    - 第二點 **加粗**

    1. 有序一
    2. 有序二

    > 引用：先想清楚問題。

    ```swift
    let x = 1
    print(x)
    ```
    """
    return ScrollView {
        MarkdownView(blocks: MarkdownParser.parse(md)).padding()
    }
    .environment(\.palette, .matteBlack)
    .background(Palette.matteBlack.bg)
}
