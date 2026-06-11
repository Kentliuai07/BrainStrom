import Foundation

// ============================================================
// 指紋與差異算法 —— 必須與網頁版逐位元一致（《整合契約 §3》）
// 鐵律：fnv1a 用 UTF-16 碼元（對齊 web charCodeAt），禁 UTF-8 bytes。
// ============================================================

enum Algo {

    /// DIFF 對象塊型（web 的 text/heading）。
    static func isDiffType(_ kind: BlockKind) -> Bool {
        kind == .paragraph || kind == .heading1 || kind == .heading2
    }

    /// 模組塊（type ∉ text/heading/todo）。
    static func isModule(_ kind: BlockKind) -> Bool { kind == .module }

    // MARK: - §3.1 normalizeText：trim + 連續空白折成一格

    static func normalizeText(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    // MARK: - §3.2 fnv1a 32bit（UTF-16 碼元）→ 8 位小寫 hex

    static func fnv1a(_ s: String) -> String {
        var h: UInt32 = 0x811c_9dc5
        for unit in s.utf16 {
            h ^= UInt32(unit)
            h = h &* 0x0100_0193   // &* = 32-bit 環繞，等同 web 的 >>>0
        }
        return String(format: "%08x", h)
    }

    /// fnvHash(s) = fnv1a(normalizeText(s))。
    static func fnvHash(_ s: String) -> String { fnv1a(normalizeText(s)) }

    // MARK: - §3.3 blockContent

    static func blockContent(_ block: Block) -> String {
        if block.kind == .module { return block.modulePayload ?? "{}" }
        return block.text
    }

    // MARK: - §3.4 fullHash（未軟刪塊按 position 排序 → normalize 後以 \n\n 串接 → fnv1a）

    static func fullHash(_ blocks: [Block]) -> String {
        let assembled = blocks
            .filter { !$0.isDeleted }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { normalizeText(blockContent($0)) }
            .joined(separator: "\n\n")
        return fnv1a(assembled)
    }

    // MARK: - §3.5 shouldSkipAi（hash gate 省錢閘）

    static func shouldSkipAi(lastAiHash: String?, blocks: [Block]) -> Bool {
        guard let last = lastAiHash, !last.isEmpty else { return false }
        return fullHash(blocks) == last
    }

    // MARK: - §3.6 nudgeHash（只取 DIFF_TYPES，不濾 pinned；前接 normalize(title)）

    static func nudgeHash(title: String, blocks: [Block]) -> String {
        let body = blocks
            .filter { !$0.isDeleted && isDiffType($0.kind) }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { normalizeText(blockContent($0)) }
            .joined(separator: "\n\n")
        let assembled = normalizeText(title) + "\n\n" + body
        return fnv1a(assembled)
    }

    // MARK: - §3.7 diffBlocks（changed 塊 id 集合）

    static func diffBlocks(_ blocks: [Block]) -> Set<UUID> {
        var changed: Set<UUID> = []
        for block in blocks where !block.isDeleted {
            guard isDiffType(block.kind), !block.isPinned else { continue }
            if block.aiHash == nil || fnvHash(blockContent(block)) != block.aiHash {
                changed.insert(block.id)
            }
        }
        return changed
    }
}
