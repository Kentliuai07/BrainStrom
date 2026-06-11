import SwiftUI

// ============================================================
// 主題（機殼）控制層
// ============================================================

/// 機殼選擇：霧面黑／暖灰機殼／跟隨系統。
enum MachineSkin: String, CaseIterable, Codable, Sendable {
    case matteBlack
    case warmGray
    case system

    var displayName: String {
        switch self {
        case .matteBlack: String(localized: "霧面黑")
        case .warmGray: String(localized: "暖灰機殼")
        case .system: String(localized: "跟隨系統")
        }
    }
}

/// 全 App 主題狀態（持久化到 UserDefaults）。
@MainActor
@Observable
final class ThemeStore {
    private static let storageKey = "machineSkin"

    var skin: MachineSkin {
        didSet { UserDefaults.standard.set(skin.rawValue, forKey: Self.storageKey) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.skin = raw.flatMap(MachineSkin.init(rawValue:)) ?? .matteBlack
    }

    /// 依目前系統外觀解析出實際色票。
    func palette(for colorScheme: ColorScheme) -> Palette {
        switch skin {
        case .matteBlack: .matteBlack
        case .warmGray: .warmGray
        case .system: colorScheme == .light ? .warmGray : .matteBlack
        }
    }

    /// 給系統 chrome（鍵盤/狀態列）的對應外觀。
    func preferredColorScheme() -> ColorScheme? {
        switch skin {
        case .matteBlack: .dark
        case .warmGray: .light
        case .system: nil
        }
    }
}

// MARK: - Environment 注入

extension EnvironmentValues {
    /// 目前生效的機殼色票；由 RootView 解析後注入，元件一律讀這個。
    @Entry var palette: Palette = .matteBlack
}
