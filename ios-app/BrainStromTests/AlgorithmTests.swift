import XCTest
@testable import BrainStrom

// ============================================================
// 算法測試 —— 指紋/diff/安全閥/切塊（《整合契約 §3》）
// 含 FNV-1a 標準向量錨點 + 跨端指紋樣本輸出
// ============================================================

final class AlgorithmTests: XCTestCase {

    // MARK: - fnv1a / normalize

    func testFnv1aStandardVectors() {
        // FNV-1a 32bit 標準測試向量（ASCII，UTF-16 與 byte 同值）
        XCTAssertEqual(Algo.fnv1a(""), "811c9dc5")
        XCTAssertEqual(Algo.fnv1a("a"), "e40c292c")
        XCTAssertEqual(Algo.fnv1a("foobar"), "bf9cf968")
    }

    func testNormalizeCollapsesWhitespace() {
        XCTAssertEqual(Algo.normalizeText("  a   b \n c "), "a b c")
        XCTAssertEqual(Algo.normalizeText("無空白"), "無空白")
        XCTAssertEqual(Algo.normalizeText("   "), "")
    }

    func testFnvHashAppliesNormalize() {
        XCTAssertEqual(Algo.fnvHash(" Hello "), Algo.fnv1a("Hello"))
        XCTAssertEqual(Algo.fnvHash("a  b"), Algo.fnv1a("a b"))
    }

    // MARK: - fullHash / shouldSkipAi

    func testFullHashStableAndIgnoresDeleted() {
        let a = Block(kind: .paragraph, text: "第一段", orderIndex: 0)
        let b = Block(kind: .paragraph, text: "第二段", orderIndex: 1)
        let deleted = Block(kind: .paragraph, text: "刪了", orderIndex: 2, deletedAt: .now)
        let h1 = Algo.fullHash([a, b, deleted])
        let h2 = Algo.fullHash([b, a])  // 順序由 orderIndex 決定、軟刪不算
        XCTAssertEqual(h1, h2)
    }

    func testShouldSkipAi() {
        let blocks = [Block(kind: .paragraph, text: "內容", orderIndex: 0)]
        let h = Algo.fullHash(blocks)
        XCTAssertTrue(Algo.shouldSkipAi(lastAiHash: h, blocks: blocks))
        XCTAssertFalse(Algo.shouldSkipAi(lastAiHash: "deadbeef", blocks: blocks))
        XCTAssertFalse(Algo.shouldSkipAi(lastAiHash: nil, blocks: blocks))
    }

    // MARK: - nudgeHash

    func testNudgeHashIgnoresModules() {
        let text = Block(kind: .paragraph, text: "點子內容", orderIndex: 0)
        let mod = Block(kind: .module, moduleKind: .table, modulePayload: "{\"x\":1}", orderIndex: 1)
        let withoutModule = Algo.nudgeHash(title: "標題", blocks: [text])
        let withModule = Algo.nudgeHash(title: "標題", blocks: [text, mod])
        XCTAssertEqual(withoutModule, withModule)  // 模組增刪不影響
    }

    // MARK: - diffBlocks

    func testDiffBlocks() {
        let unchanged = Block(kind: .paragraph, text: "穩定", orderIndex: 0, aiHash: Algo.fnvHash("穩定"))
        let changed = Block(kind: .paragraph, text: "改過了", orderIndex: 1, aiHash: "old")
        let fresh = Block(kind: .paragraph, text: "新塊", orderIndex: 2)            // aiHash nil → changed
        let pinned = Block(kind: .paragraph, text: "釘住", isPinned: true, orderIndex: 3)
        let module = Block(kind: .module, orderIndex: 4)
        let result = Algo.diffBlocks([unchanged, changed, fresh, pinned, module])
        XCTAssertEqual(result, [changed.id, fresh.id])
    }

    // MARK: - checkOptimizePatch 安全閥

    func testValveOK() {
        let b = Block(kind: .paragraph, text: "原本內容大約這麼長", orderIndex: 0)
        let patch = OptimizePatch(updates: [.init(id: b.id.uuidString, content: "原本內容大約這麼長一點")])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [b], patch: patch, changedIds: [b.id], mode: .optimize), .ok)
    }

    func testValveTouchRatioReject() {
        let a = Block(kind: .paragraph, text: "甲", orderIndex: 0)
        let b = Block(kind: .paragraph, text: "乙", orderIndex: 1)
        let patch = OptimizePatch(updates: [
            .init(id: a.id.uuidString, content: "甲改"), .init(id: b.id.uuidString, content: "乙改"),
        ])
        // changedIds 只有 1 個，但動了 2 個 → touch_ratio
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [a, b], patch: patch, changedIds: [a.id], mode: .optimize),
                       .rejected(.touchRatio))
    }

    func testValveTouchForbiddenPinned() {
        let normal = Block(kind: .paragraph, text: "一般", orderIndex: 0)
        let pinned = Block(kind: .paragraph, text: "釘住", isPinned: true, orderIndex: 1)
        let patch = OptimizePatch(updates: [.init(id: pinned.id.uuidString, content: "想改釘住的")])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [normal, pinned], patch: patch,
                                               changedIds: [normal.id], mode: .optimize),
                       .rejected(.touchForbidden))
    }

    func testValveChangeRatioReject() {
        let b = Block(kind: .paragraph, text: "短", orderIndex: 0)   // 正規化長度 1
        let patch = OptimizePatch(updates: [.init(id: b.id.uuidString, content: "這是一段遠遠超過原文長度的內容會被擋下")])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [b], patch: patch, changedIds: [b.id], mode: .optimize),
                       .rejected(.changeRatio))
    }

    func testValveIllegalRemoveAndLegal() {
        let removed = Block(kind: .paragraph, text: "蘋果香蕉", orderIndex: 0)
        let kept = Block(kind: .paragraph, text: "蘋果香蕉橘子", orderIndex: 1)
        // 合法合併：被刪內容片段出現在 update 裡（update 只小改 1 字，避免觸發 change_ratio）
        let legal = OptimizePatch(updates: [.init(id: kept.id.uuidString, content: "蘋果香蕉橘子甜")],
                                  removes: [removed.id.uuidString])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [removed, kept], patch: legal,
                                               changedIds: [removed.id, kept.id], mode: .optimize), .ok)
        // 非法刪除：沒有 update 承接
        let illegal = OptimizePatch(removes: [removed.id.uuidString])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [removed, kept], patch: illegal,
                                               changedIds: [removed.id], mode: .optimize),
                       .rejected(.illegalRemove))
    }

    func testValveBadAdd() {
        let patchType = OptimizePatch(adds: [.init(type: "todo", content: "x", position: 0)])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [], patch: patchType, changedIds: [], mode: .optimize),
                       .rejected(.badAdd))
        let patchEmpty = OptimizePatch(adds: [.init(type: "text", content: "   ", position: 0)])
        XCTAssertEqual(Algo.checkOptimizePatch(blocks: [], patch: patchEmpty, changedIds: [], mode: .optimize),
                       .rejected(.badAdd))
    }

    // MARK: - checkStructureCards

    func testStructureCards() {
        XCTAssertEqual(Algo.checkStructureCards(blocks: [], cards: []), .rejected(.emptyCards))
        let emptyContent = [StructureCard(type: "text", title: "標題", content: "  ", absorbed: [])]
        XCTAssertEqual(Algo.checkStructureCards(blocks: [], cards: emptyContent), .rejected(.emptyCard))
        let pinned = Block(kind: .paragraph, text: "釘", isPinned: true, orderIndex: 0)
        let touchPinned = [StructureCard(type: "text", title: "T", content: "C", absorbed: [pinned.id.uuidString])]
        XCTAssertEqual(Algo.checkStructureCards(blocks: [pinned], cards: touchPinned), .rejected(.touchPinned))
        let ok = [StructureCard(type: "text", title: "T", content: "C", absorbed: [])]
        XCTAssertEqual(Algo.checkStructureCards(blocks: [pinned], cards: ok), .ok)
    }

    // MARK: - splitIntoBlocks

    func testSplitParagraphsAndHeadings() {
        let blocks = Algo.splitIntoBlocks("# 大標\n第一段\n還是第一段\n\n第二段\n## 小標")
        XCTAssertEqual(blocks.map { $0.kind }, [.heading1, .paragraph, .paragraph, .heading2])
        XCTAssertEqual(blocks[0].text, "大標")
        XCTAssertEqual(blocks[1].text, "第一段\n還是第一段")
        XCTAssertEqual(blocks[3].text, "小標")
    }

    func testSplitFenceUncut() {
        let code = "前言\n\n```swift\nlet x = 1\n\nlet y = 2\n```\n結尾"
        let blocks = Algo.splitIntoBlocks(code)
        XCTAssertEqual(blocks.count, 3)              // 前言 / 整段 code / 結尾
        XCTAssertTrue(blocks[1].text.contains("let x = 1"))
        XCTAssertTrue(blocks[1].text.contains("let y = 2"))  // 圍欄內空行不切
    }

    // MARK: - 跨端指紋樣本輸出（寫進 docs/iOS指纹样本.md 給後端比對）

    func testPrintFingerprintSamples() {
        let samples = ["", "a", "Hello", "測試 Hello  世界", "  前後空白  trim 測試  "]
        print("=== FNV FINGERPRINT SAMPLES (iOS) ===")
        for s in samples {
            print("SAMPLE|\(s)|fnv1a=\(Algo.fnv1a(s))|fnvHash=\(Algo.fnvHash(s))")
        }
        print("=== END SAMPLES ===")
    }
}
