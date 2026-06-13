import SwiftUI

// ============================================================
// 打字機緩衝器 —— 把 AI 串流「一坨 ~18 字」的 delta 解耦成「逐字平滑播放」
// 真因：Anthropic 的 text_delta 本身就是多字 chunk（實測每 ~0.47s 一條、每條 ~18 字），
// 前端一收到整坨就渲染整坨 → 一排排蹦。本緩衝器以固定節拍逐字吐出，與網路到達速率脫鉤。
// 教練對話與（未來）批量定位卡 streamingText 共用。
// ============================================================

@MainActor
@Observable
final class TypewriterBuffer {

    /// 目前該顯示的文字（逐字推進；View 觀察這個）。
    private(set) var shown: String = ""

    private var full: String = ""        // 累積到目前的完整文字（目標）
    private var shownCount: Int = 0      // 已顯示字數
    private var ticker: Task<Void, Never>?

    /// 每幀節拍（毫秒）。約 16ms ≈ 60fps。
    private let tickMs: Int

    init(tickMs: Int = 16) { self.tickMs = tickMs }

    func reset() {
        ticker?.cancel(); ticker = nil
        shown = ""; full = ""; shownCount = 0
    }

    /// 串流每收到新增量就更新目標（傳「累積後的完整文字」，只增不減）。
    func setTarget(_ text: String) {
        full = text
        if ticker == nil { startTicking() }
    }

    /// 串流結束：立刻補完剩餘、停表（之後 View 切回 markdown 定稿）。
    func finish() {
        ticker?.cancel(); ticker = nil
        shownCount = full.count
        shown = full
    }

    private func startTicking() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let fullCount = self.full.count
                if self.shownCount < fullCount {
                    // 落後越多吐越快（自適應），最少 1 字，避免長回覆追不上。
                    let behind = fullCount - self.shownCount
                    let step = max(1, behind / 8)
                    self.shownCount = min(self.shownCount + step, fullCount)
                    self.shown = String(self.full.prefix(self.shownCount))
                }
                try? await Task.sleep(for: .milliseconds(self.tickMs))
            }
        }
    }
}
