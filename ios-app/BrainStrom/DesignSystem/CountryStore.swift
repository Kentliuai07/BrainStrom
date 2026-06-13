import SwiftUI

// ============================================================
// 目标国家 · 全局记忆 —— 选过一次就记住(UserDefaults),下次建专案不用重选。
// 影响 persona 生成策略 + Exa/GitHub 搜寻语言/地区。
// ============================================================

@MainActor
@Observable
final class CountryStore {

    struct Country: Identifiable, Hashable, Sendable {
        let code: String     // 传给后端 COUNTRY_MAP 的 key
        let label: String    // UI 显示
        var id: String { code }
    }

    /// 预设选项（下拉菜单）。
    static let presets: [Country] = [
        .init(code: "TW", label: "🇹🇼 台灣 / 繁中"),
        .init(code: "CN", label: "🇨🇳 中国 / 简中"),
        .init(code: "US", label: "🇺🇸 美國 / English"),
        .init(code: "JP", label: "🇯🇵 日本 / 日本語"),
    ]

    private let key = "persona.targetCountry"

    /// 目前选的国家码；改动即写入 UserDefaults（记忆）。
    var code: String {
        didSet { UserDefaults.standard.set(code, forKey: key) }
    }

    init() {
        code = UserDefaults.standard.string(forKey: key) ?? "TW"
    }

    var label: String {
        Self.presets.first { $0.code == code }?.label ?? code
    }
}
