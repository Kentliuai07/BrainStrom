import SwiftUI

// ============================================================
// 全域回饋：Toast 膠囊 + 離線橫條
// （對齊 web frame()：每個畫面都掛在最上層；工業橘皮）
// ============================================================

/// 全 App 共用的 Toast 狀態（對齊 web 的 app.toast）。
@MainActor
@Observable
final class ToastModel {
    private(set) var message: String?
    private var token = 0

    /// 顯示一則 Toast，1.3 秒後自動退場（與 web 同步）。
    func show(_ text: String) {
        message = text
        token += 1
        let mine = token
        Haptics.tap()
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            if mine == token { withAnimation(Motion.layer) { message = nil } }
        }
    }
}

/// Toast 膠囊（橘鍵帽臉、底部上浮）。
struct ToastBanner: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.body(12.5, weight: .bold))
            .foregroundStyle(palette.orangeInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.orange)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}

/// 離線橫條（頂部下落；web 的 #offbar）。
struct OfflineBar: View {
    let online: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        if !online {
            Text(String(localized: "⚠ 目前離線，變更暫存本地"))
                .font(Tokens.Fonts.body(12, weight: .semibold))
                .foregroundStyle(palette.print)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(palette.danger.opacity(0.18))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(palette.danger.opacity(0.4)).frame(height: 1)
                }
                .transition(.move(edge: .top))
        }
    }
}
