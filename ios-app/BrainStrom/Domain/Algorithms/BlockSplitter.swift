import Foundation

// ============================================================
// §3.13 splitIntoBlocks —— 續寫文字切成塊
// 規則：``` 圍欄整段一塊不切；連續空行=段界；行首 # 獨立成 heading
//（# 數 >1 → level2 否則 level1）；其餘累積成 text 塊。
// ============================================================

extension Algo {

    static func splitIntoBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var order = 0
        var textBuffer: [String] = []
        var inFence = false
        var fenceBuffer: [String] = []

        func append(_ kind: BlockKind, _ content: String) {
            blocks.append(Block(kind: kind, text: content, orderIndex: order))
            order += 1
        }
        func flushText() {
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { append(.paragraph, joined) }
            textBuffer.removeAll()
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inFence {
                    fenceBuffer.append(line)
                    append(.paragraph, fenceBuffer.joined(separator: "\n"))
                    fenceBuffer.removeAll()
                    inFence = false
                } else {
                    flushText()
                    inFence = true
                    fenceBuffer = [line]
                }
                continue
            }
            if inFence { fenceBuffer.append(line); continue }

            if trimmed.isEmpty { flushText(); continue }

            if trimmed.hasPrefix("#") {
                flushText()
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                let content = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                append(hashes > 1 ? .heading2 : .heading1, String(content))
                continue
            }

            textBuffer.append(line)
        }

        if inFence && !fenceBuffer.isEmpty { append(.paragraph, fenceBuffer.joined(separator: "\n")) }
        flushText()
        return blocks
    }
}
