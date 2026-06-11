import SwiftUI

// ============================================================
// 設計 Tokens —— 與 `ios-app/design/tokens.css` 1:1 對應（唯一來源）
// 世界觀：App 是一台筆記儀器（工業硬體）
// ============================================================

/// 全域設計常數（間距、字階、圓角、缺角、動效）。
enum Tokens {

    /// 間距（pt）：4 / 8 / 12 / 16 / 20 / 24 / 32，頁邊 20。
    enum Spacing {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        static let pageX: CGFloat = 20
    }

    /// 圓角（pt）。
    enum Radius {
        static let card: CGFloat = 14
        static let key: CGFloat = 9
        static let input: CGFloat = 10
        static let pill: CGFloat = 999
    }

    /// 缺角簽名：卡右上 45° 切 12pt；直條左上切 16pt。
    enum Notch {
        static let card: CGFloat = 12
        static let rail: CGFloat = 16
    }

    /// 字階（pt）。
    enum FontSize {
        static let h1: CGFloat = 32
        static let h2: CGFloat = 22
        static let body: CGFloat = 17
        static let sub: CGFloat = 15
        static let caption: CGFloat = 12
        static let print: CGFloat = 10.5
        static let stencil: CGFloat = 9
    }

    /// 字體（全部 iOS 系統內建，零第三方）。
    enum Fonts {
        /// 銘板/大字標：Avenir Next Condensed。
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            let name: String
            switch weight {
            case .heavy, .black: name = "AvenirNextCondensed-Heavy"
            case .bold: name = "AvenirNextCondensed-Bold"
            case .semibold: name = "AvenirNextCondensed-DemiBold"
            case .medium: name = "AvenirNextCondensed-Medium"
            default: name = "AvenirNextCondensed-Regular"
            }
            return .custom(name, size: size)
        }

        /// 機身印刷/數據：SF Mono（系統 monospaced）。
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        /// 內文：SF Pro / PingFang TC。
        static func body(_ size: CGFloat = FontSize.body, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
    }

    /// 模板印刷字距（letter-spacing，pt 近似 CSS em 值）。
    enum Kerning {
        static let stencil: CGFloat = 2.4   // .26em @ 9pt
        static let print: CGFloat = 1.2     // .12em @ 10.5pt
    }

    /// 鍵帽按壓行程（pt）。
    static let keyTravel: CGFloat = 2.5
}

/// 動效 —— 禁線性 ease；關鍵動作一律 spring。
enum Motion {
    /// 標準 spring（CSS cubic-bezier(.30,1.22,.42,1) 的對應）。
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// 浮層進出。
    static let layer = Animation.easeOut(duration: 0.25)
    /// 直條滑入。
    static let rail = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// 鍵帽行程。
    static let key = Animation.easeOut(duration: 0.12)
    /// 進場 stagger 間隔（秒）。
    static let stagger: Double = 0.04
    /// LED 呼吸週期（秒）。
    static let ledPulse: Double = 2.4
}

// MARK: - 機殼色票

/// 一套機殼的完整語義色（= tokens.css 的 CSS 變數）。
struct Palette: Equatable, Sendable {
    let bg: Color           // 機殼
    let panel: Color        // 面板
    let panel2: Color       // 浮起鍵帽
    let recess: Color       // 凹槽
    let line: Color         // 折線
    let lineStrong: Color   // 結構邊
    let print: Color        // 印刷主文字
    let print2: Color       // 次級印刷
    let print3: Color       // 微印刷
    let orange: Color       // TE 橘＝唯一主強調
    let orangeDeep: Color   // 鍵帽側面
    let orangeDim: Color    // 橘色弱底
    let orangeInk: Color    // 橘鍵上的字
    let ledGreen: Color
    let ledAmber: Color
    let ledRed: Color
    let danger: Color
    let scrim: Color        // 全屏調光
}

extension Palette {

    /// 主題 A：霧面黑（預設）。
    static let matteBlack = Palette(
        bg: Color(hex: 0x1A1A18),
        panel: Color(hex: 0x222220),
        panel2: Color(hex: 0x2A2A27),
        recess: Color(hex: 0x141412),
        line: Color(hex: 0x3A3A36),
        lineStrong: Color(hex: 0x4A4A45),
        print: Color(hex: 0xE8E4D8),
        print2: Color(hex: 0x8E8B80),
        print3: Color(hex: 0x5C5A52),
        orange: Color(hex: 0xFF4D00),
        orangeDeep: Color(hex: 0xA03000),
        orangeDim: Color(hex: 0xFF4D00, alpha: 0.12),
        orangeInk: Color(hex: 0x16100B),
        ledGreen: Color(hex: 0x54D62C),
        ledAmber: Color(hex: 0xFFB000),
        ledRed: Color(hex: 0xFF453A),
        danger: Color(hex: 0xFF5A47),
        scrim: Color(hex: 0x080806, alpha: 0.42)
    )

    /// 主題 B：暖灰機殼（同一台機器的灰白塑料版）。
    static let warmGray = Palette(
        bg: Color(hex: 0xE6E4DE),
        panel: Color(hex: 0xEFEDE7),
        panel2: Color(hex: 0xF7F5F0),
        recess: Color(hex: 0xDBD8D0),
        line: Color(hex: 0xC9C6BD),
        lineStrong: Color(hex: 0xA8A59B),
        print: Color(hex: 0x262521),
        print2: Color(hex: 0x6E6C63),
        print3: Color(hex: 0x9B988D),
        orange: Color(hex: 0xE84200),
        orangeDeep: Color(hex: 0x9C2E00),
        orangeDim: Color(hex: 0xE84200, alpha: 0.10),
        orangeInk: Color(hex: 0xFFF4EC),
        ledGreen: Color(hex: 0x2FA414),
        ledAmber: Color(hex: 0xD98F00),
        ledRed: Color(hex: 0xE5342B),
        danger: Color(hex: 0xC8321F),
        scrim: Color(hex: 0x3C3830, alpha: 0.30)
    )
}

// MARK: - Color hex 便利建構

extension Color {
    /// 以 0xRRGGBB 建色（設計稿色票直填）。
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
