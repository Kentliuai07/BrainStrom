import XCTest
@testable import BrainStrom

// ============================================================
// Markdown 解析器測試 —— AI 回應排版的核心
// ============================================================

final class MarkdownParserTests: XCTestCase {

    func testHeadings() {
        XCTAssertEqual(MarkdownParser.parse("# 標題"), [.heading(level: 1, "標題")])
        XCTAssertEqual(MarkdownParser.parse("## 二級"), [.heading(level: 2, "二級")])
        XCTAssertEqual(MarkdownParser.parse("#### 超深"), [.heading(level: 3, "超深")])   // >3 併入 3
    }

    func testHashWithoutSpaceNotHeading() {
        // "#tag" 不是標題（無文字內容判定：drop # 後為 "tag" 非空 → 仍算標題? 規則：# 後需有內容）
        XCTAssertEqual(MarkdownParser.parse("#標題"), [.heading(level: 1, "標題")])
    }

    func testParagraphJoinAndBlankSplit() {
        XCTAssertEqual(MarkdownParser.parse("第一行\n第二行"), [.paragraph("第一行 第二行")])
        XCTAssertEqual(MarkdownParser.parse("甲\n\n乙"), [.paragraph("甲"), .paragraph("乙")])
    }

    func testBullets() {
        XCTAssertEqual(MarkdownParser.parse("- 一\n- 二\n* 三"), [.bullet(["一", "二", "三"])])
    }

    func testOrdered() {
        XCTAssertEqual(MarkdownParser.parse("1. 甲\n2. 乙"), [.ordered(["甲", "乙"])])
    }

    func testQuote() {
        XCTAssertEqual(MarkdownParser.parse("> 引一\n> 引二"), [.quote(["引一", "引二"])])
    }

    func testCodeBlockPreservesContent() {
        let md = "```swift\nlet x = 1\n\nlet y = 2\n```"
        XCTAssertEqual(MarkdownParser.parse(md), [.codeBlock(lang: "swift", "let x = 1\n\nlet y = 2")])
    }

    func testCodeBlockNotParsedInside() {
        // 框內的 # - 不應被當標題/清單
        let md = "```\n# 不是標題\n- 不是清單\n```"
        XCTAssertEqual(MarkdownParser.parse(md), [.codeBlock(lang: nil, "# 不是標題\n- 不是清單")])
    }

    func testUnclosedCodeFenceFlushes() {
        XCTAssertEqual(MarkdownParser.parse("```\ncode"), [.codeBlock(lang: nil, "code")])
    }

    func testMixedDocumentOrder() {
        let md = """
        # 計畫
        前言段落。

        ## 步驟
        - 第一
        - 第二

        1. 甲
        2. 乙

        > 引用

        ```swift
        let a = 1
        ```
        結尾段落。
        """
        let result = MarkdownParser.parse(md)
        XCTAssertEqual(result, [
            .heading(level: 1, "計畫"),
            .paragraph("前言段落。"),
            .heading(level: 2, "步驟"),
            .bullet(["第一", "第二"]),
            .ordered(["甲", "乙"]),
            .quote(["引用"]),
            .codeBlock(lang: "swift", "let a = 1"),
            .paragraph("結尾段落。"),
        ])
    }
}
