import Foundation

// ============================================================
// 安全閥 —— 程式判定、不信 AI；拒絕即整批不動（《整合契約 §3.8/3.9》）
// ============================================================

/// 優化模式（影響 ratioCap 與 touchSet 範圍）。
enum OptimizeMode: Sendable {
    case optimize       // ratioCap 0.3；touchSet=本次 changed
    case instruction    // ratioCap 2.0；touchSet=全部未釘選 DIFF_TYPES（對話式編輯）
}

/// optimize/applyEdit 收到的 patch（由 card_done/card_removed 組成）。
struct OptimizePatch: Equatable, Sendable {
    struct Add: Equatable, Sendable { let type: String; let content: String; let position: Int }
    struct Update: Equatable, Sendable { let id: String; let content: String }
    var adds: [Add] = []
    var updates: [Update] = []
    var removes: [String] = []   // 被刪塊 id
}

/// structure 收到的卡片（card_done structure 形狀）。
struct StructureCard: Equatable, Sendable {
    let type: String?
    let title: String?
    let content: String?
    let absorbed: [String]
}

/// 安全閥拒絕原因（= server/網頁的 error code）。
enum PatchRejection: String, Equatable, Sendable {
    case touchRatio = "touch_ratio"
    case unknownBlock = "unknown_block"
    case touchForbidden = "touch_forbidden"
    case changeRatio = "change_ratio"
    case illegalRemove = "illegal_remove"
    case badAdd = "bad_add"
}

enum StructureRejection: String, Equatable, Sendable {
    case emptyCards = "empty_cards"
    case emptyCard = "empty_card"
    case touchPinned = "touch_pinned"
}

enum PatchVerdict: Equatable, Sendable {
    case ok
    case rejected(PatchRejection)
}

enum StructureVerdict: Equatable, Sendable {
    case ok
    case rejected(StructureRejection)
}

extension Algo {

    // MARK: - §3.8 checkOptimizePatch

    static func checkOptimizePatch(blocks: [Block], patch: OptimizePatch,
                                   changedIds: Set<UUID>, mode: OptimizeMode) -> PatchVerdict {
        let ratioCap = mode == .instruction ? 2.0 : 0.3
        let byId: [String: Block] = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id.uuidString, $0) })

        // touchSet
        let touchSet: Set<String>
        switch mode {
        case .optimize:
            touchSet = Set(changedIds.map { $0.uuidString })
        case .instruction:
            touchSet = Set(blocks.filter { !$0.isDeleted && isDiffType($0.kind) && !$0.isPinned }
                .map { $0.id.uuidString })
        }

        // touch_ratio：動到的塊數 > touchSet 大小 → 拒
        if patch.updates.count + patch.removes.count > touchSet.count {
            return .rejected(.touchRatio)
        }

        // updates 逐條
        for update in patch.updates {
            guard let block = byId[update.id] else { return .rejected(.unknownBlock) }
            if block.isPinned || isModule(block.kind) || !touchSet.contains(update.id) {
                return .rejected(.touchForbidden)
            }
            let oldLen = normalizeText(blockContent(block)).count
            let newLen = normalizeText(update.content).count
            let delta = abs(newLen - oldLen)
            if Double(delta) > Double(max(oldLen, 1)) * ratioCap {
                return .rejected(.changeRatio)
            }
        }

        // removes 逐條（含刪除合法性）
        let combinedUpdates = patch.updates.map { stripForCompare($0.content) }.joined()
        for removeId in patch.removes {
            guard let block = byId[removeId] else { return .rejected(.unknownBlock) }
            if block.isPinned || isModule(block.kind) || !touchSet.contains(removeId) {
                return .rejected(.touchForbidden)
            }
            if !isLegalRemove(removed: blockContent(block), within: combinedUpdates) {
                return .rejected(.illegalRemove)
            }
        }

        // adds 逐條
        for add in patch.adds {
            if add.type != "text" && add.type != "heading" { return .rejected(.badAdd) }
            if normalizeText(add.content).isEmpty { return .rejected(.badAdd) }
        }

        return .ok
    }

    /// 刪除合法性：被刪塊內容去空白標點後，≥50% 長度連續片段出現在某 update（空塊可刪）。
    static func isLegalRemove(removed: String, within combinedUpdates: String) -> Bool {
        let r = Array(stripForCompare(removed))
        if r.isEmpty { return true }
        let need = Int(ceil(Double(r.count) * 0.5))
        guard need >= 1, need <= r.count else { return true }
        for start in 0...(r.count - need) {
            let fragment = String(r[start..<(start + need)])
            if combinedUpdates.contains(fragment) { return true }
        }
        return false
    }

    /// 去空白與標點（比對連續片段用）。
    static func stripForCompare(_ s: String) -> String {
        let drop = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
        return String(String.UnicodeScalarView(s.unicodeScalars.filter { !drop.contains($0) }))
    }

    // MARK: - §3.9 checkStructureCards

    static func checkStructureCards(blocks: [Block], cards: [StructureCard]) -> StructureVerdict {
        if cards.isEmpty { return .rejected(.emptyCards) }
        let byId: [String: Block] = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id.uuidString, $0) })
        for card in cards {
            if (card.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (card.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .rejected(.emptyCard)
            }
            for absorbedId in card.absorbed {
                if let block = byId[absorbedId], block.isPinned || isModule(block.kind) {
                    return .rejected(.touchPinned)
                }
            }
        }
        return .ok
    }
}
