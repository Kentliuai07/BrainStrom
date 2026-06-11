import UIKit

// ============================================================
// 觸覺回饋 —— 規格書 §2：關鍵操作必有 Haptics
// ============================================================

/// 全 App 統一觸覺入口（語義化命名，禁止散裝呼叫 UIKit generator）。
@MainActor
enum Haptics {

    /// 輕觸（選取、滑動吸附）。
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 按壓（鍵帽、FAB、拖曳起手）。
    static func press() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 切換（撥動開關、機殼色票）。
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 成功（AI 完成、儲存）。
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告（危險區、刪除確認）。
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// 錯誤（登入失敗、網路錯誤）。
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
