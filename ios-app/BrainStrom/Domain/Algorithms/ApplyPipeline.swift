import Foundation

// ============================================================
// AI 套用管線（純函式）—— 安全閥通過後算出「新塊陣列＋新指紋＋docState」
// 對齊《整合契約 §3.10/3.11/3.12》。落庫與版本快照由 NoteDocument（步驟7）呼叫。
// ============================================================

/// 優化套用結果。
enum OptimizeApply: Equatable, Sendable {
    case rejected(PatchRejection)
    case applied(blocks: [Block], lastAiHash: String, docState: DocState)
}

/// 結構化套用結果。
enum StructureApply: Equatable, Sendable {
    case rejected(StructureRejection)
    case applied(blocks: [Block], lastAiHash: String)
}

extension Algo {

    // MARK: - §3.10 computeStructuredBlocks

    /// 保留（模組或釘選）塊＋卡轉新文字塊，按原 position 穿插回。
    static func computeStructuredBlocks(blocks: [Block], cards: [StructureCard]) -> [Block] {
        let live = blocks.filter { !$0.isDeleted }.sorted { $0.orderIndex < $1.orderIndex }
        // 保留＝非（DIFF_TYPES 且未釘選）：模組塊、釘選塊恆留
        let kept = live.filter { !(isDiffType($0.kind) && !$0.isPinned) }
        let gen = (blocks.map(\.structureGen).max() ?? 0) + 1

        var result: [Block] = cards.enumerated().map { index, card in
            let content = card.content ?? ""
            return Block(kind: .paragraph, text: content, isPinned: false,
                         orderIndex: index, source: .ai,
                         aiHash: fnvHash(content), structureGen: gen,
                         cardTitle: card.title)
        }
        // 保留塊按原 position 穿插（min(max(0,pos), len)）
        for block in kept {
            let idx = min(max(0, block.orderIndex), result.count)
            result.insert(block, at: idx)
        }
        for i in result.indices { result[i].orderIndex = i }
        return result
    }

    // MARK: - §3.11 applyOptimizePatch

    static func applyOptimizePatch(blocks: [Block], patch: OptimizePatch,
                                   changedIds: Set<UUID>, mode: OptimizeMode,
                                   docState: DocState, now: Date) -> OptimizeApply {
        if case let .rejected(reason) = checkOptimizePatch(blocks: blocks, patch: patch,
                                                           changedIds: changedIds, mode: mode) {
            return .rejected(reason)   // 零變動
        }

        var working = blocks
        func indexOf(_ idStr: String) -> Int? { working.firstIndex { $0.id.uuidString == idStr } }

        // updates：改文字＋寫新 aiHash
        for update in patch.updates {
            guard let i = indexOf(update.id) else { continue }
            working[i].text = update.content
            working[i].aiHash = fnvHash(update.content)
        }
        // removes：軟刪
        for removeId in patch.removes {
            guard let i = indexOf(removeId) else { continue }
            working[i].deletedAt = now
        }
        // adds：依 position 穿插進 live 序列
        var live = working.filter { !$0.isDeleted }.sorted { $0.orderIndex < $1.orderIndex }
        for add in patch.adds.sorted(by: { $0.position < $1.position }) {
            let kind: BlockKind = add.type == "heading" ? .heading1 : .paragraph
            let block = Block(kind: kind, text: add.content, source: .ai, aiHash: fnvHash(add.content))
            let idx = min(max(0, add.position), live.count)
            live.insert(block, at: idx)
        }
        for i in live.indices { live[i].orderIndex = i }
        let deleted = working.filter { $0.isDeleted }
        let result = live + deleted

        let newDocState: DocState
        switch mode {
        case .optimize:     newDocState = docState == .carded ? .carded : .optimized
        case .instruction:  newDocState = docState   // 不降級
        }
        return .applied(blocks: result, lastAiHash: fullHash(result), docState: newDocState)
    }

    // MARK: - §3.12 applyStructureCards

    static func applyStructureCards(blocks: [Block], cards: [StructureCard]) -> StructureApply {
        if case let .rejected(reason) = checkStructureCards(blocks: blocks, cards: cards) {
            return .rejected(reason)   // 零變動
        }
        let result = computeStructuredBlocks(blocks: blocks, cards: cards)
        return .applied(blocks: result, lastAiHash: fullHash(result))
    }
}
