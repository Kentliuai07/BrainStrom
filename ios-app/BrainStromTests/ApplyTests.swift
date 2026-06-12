import XCTest
@testable import BrainStrom

// ============================================================
// 套用管線測試（《整合契約 §3.10/3.11/3.12》）
// ============================================================

final class ApplyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - computeStructuredBlocks

    func testComputeKeepsModuleAndPinned() {
        let plain = Block(kind: .paragraph, text: "一般文字", orderIndex: 0)
        let module = Block(kind: .module, moduleKind: .table, modulePayload: "{}", orderIndex: 1)
        let pinned = Block(kind: .paragraph, text: "釘住", isPinned: true, orderIndex: 2)
        let cards = [
            StructureCard(type: "text", title: "卡一", content: "內容一", absorbed: []),
            StructureCard(type: "text", title: "卡二", content: "內容二", absorbed: []),
        ]
        let result = Algo.computeStructuredBlocks(blocks: [plain, module, pinned], cards: cards)
        // 一般文字塊被吸收消失；模組＋釘選保留；2 張新卡塊
        XCTAssertTrue(result.contains { $0.id == module.id })
        XCTAssertTrue(result.contains { $0.id == pinned.id })
        XCTAssertFalse(result.contains { $0.id == plain.id })
        let newCards = result.filter { $0.source == .ai }
        XCTAssertEqual(newCards.count, 2)
        XCTAssertEqual(newCards.first?.cardTitle, "卡一")
        XCTAssertEqual(newCards.first?.aiHash, Algo.fnvHash("內容一"))
    }

    func testComputeGenIncrement() {
        let b = Block(kind: .paragraph, text: "x", orderIndex: 0, structureGen: 2)
        let result = Algo.computeStructuredBlocks(blocks: [b],
            cards: [StructureCard(type: "text", title: "T", content: "C", absorbed: [])])
        XCTAssertEqual(result.first { $0.source == .ai }?.structureGen, 3)
    }

    // MARK: - applyOptimizePatch

    func testApplyOptimizeUpdate() {
        let b = Block(kind: .paragraph, text: "原本內容", orderIndex: 0)
        let patch = OptimizePatch(updates: [.init(id: b.id.uuidString, content: "原本內容改")])
        let result = Algo.applyOptimizePatch(blocks: [b], patch: patch, changedIds: [b.id],
                                             mode: .optimize, docState: .raw, now: now)
        guard case let .applied(blocks, lastAiHash, docState) = result else { return XCTFail("未套用") }
        XCTAssertEqual(blocks.first?.text, "原本內容改")
        XCTAssertEqual(blocks.first?.aiHash, Algo.fnvHash("原本內容改"))
        XCTAssertEqual(docState, .optimized)
        XCTAssertEqual(lastAiHash, Algo.fullHash(blocks))
    }

    func testApplyOptimizeRejectedZeroChange() {
        let b = Block(kind: .paragraph, text: "短", orderIndex: 0)
        let patch = OptimizePatch(updates: [.init(id: b.id.uuidString, content: "暴增超長內容遠超原文長度上限")])
        let result = Algo.applyOptimizePatch(blocks: [b], patch: patch, changedIds: [b.id],
                                             mode: .optimize, docState: .raw, now: now)
        XCTAssertEqual(result, .rejected(.changeRatio))
    }

    func testApplyOptimizeRemoveSoftDeletes() {
        let removed = Block(kind: .paragraph, text: "蘋果香蕉", orderIndex: 0)
        let kept = Block(kind: .paragraph, text: "蘋果香蕉橘子", orderIndex: 1)
        let patch = OptimizePatch(updates: [.init(id: kept.id.uuidString, content: "蘋果香蕉橘子甜")],
                                  removes: [removed.id.uuidString])
        let result = Algo.applyOptimizePatch(blocks: [removed, kept], patch: patch,
                                             changedIds: [removed.id, kept.id], mode: .optimize,
                                             docState: .raw, now: now)
        guard case let .applied(blocks, _, _) = result else { return XCTFail("未套用") }
        XCTAssertTrue(blocks.first { $0.id == removed.id }?.isDeleted == true)   // 軟刪保留可復活
        XCTAssertEqual(blocks.filter { !$0.isDeleted }.count, 1)                  // live 只剩 kept
    }

    func testApplyOptimizeInstructionNoDowngrade() {
        let b = Block(kind: .paragraph, text: "內容", orderIndex: 0)
        let patch = OptimizePatch(updates: [.init(id: b.id.uuidString, content: "內容微調")])
        let result = Algo.applyOptimizePatch(blocks: [b], patch: patch, changedIds: [b.id],
                                             mode: .instruction, docState: .carded, now: now)
        guard case let .applied(_, _, docState) = result else { return XCTFail("未套用") }
        XCTAssertEqual(docState, .carded)   // instruction 不降級
    }

    // MARK: - applyStructureCards

    func testApplyStructureCards() {
        let b = Block(kind: .paragraph, text: "草稿", orderIndex: 0)
        let cards = [StructureCard(type: "text", title: "T", content: "C", absorbed: [])]
        let result = Algo.applyStructureCards(blocks: [b], cards: cards)
        guard case let .applied(blocks, lastAiHash) = result else { return XCTFail("未套用") }
        XCTAssertEqual(blocks.filter { $0.source == .ai }.count, 1)
        XCTAssertEqual(lastAiHash, Algo.fullHash(blocks))
    }

    func testApplyStructureRejectsEmpty() {
        XCTAssertEqual(Algo.applyStructureCards(blocks: [], cards: []), .rejected(.emptyCards))
    }
}
