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

// MARK: - Skin 形/影/字/動 結構（換皮用 · additive，舊皮免動）

/// 形：圓角、缺角、邊框、命中區。換皮把「形」收進中央層。
struct SkinMetrics: Equatable, Sendable {
    var radiusCard: CGFloat
    var radiusKey: CGFloat
    var radiusInput: CGFloat
    var notchCard: CGFloat
    var notchRail: CGFloat
    var border: CGFloat
    var hitTarget: CGFloat

    /// 工業儀器（現況：圓角＋缺角＋細邊）。
    static let instrument = SkinMetrics(
        radiusCard: Tokens.Radius.card, radiusKey: Tokens.Radius.key, radiusInput: Tokens.Radius.input,
        notchCard: Tokens.Notch.card, notchRail: Tokens.Notch.rail, border: 1, hitTarget: 44)
    /// 野獸派（直角、無缺角、3px 黑邊、48 命中）。
    static let brutal = SkinMetrics(
        radiusCard: 0, radiusKey: 0, radiusInput: 0,
        notchCard: 0, notchRail: 0, border: 3, hitTarget: 48)
}

/// 影：陰影語法（soft＝柔光；hard＝實心位移塊，零模糊）。
struct SkinShadow: Equatable, Sendable {
    enum Style: Sendable { case soft, hard }
    var style: Style
    var dx: CGFloat
    var dy: CGFloat
    var blur: CGFloat
    var opacity: Double

    static let soft = SkinShadow(style: .soft, dx: 0, dy: 8, blur: 20, opacity: 0.5)
    static let hard = SkinShadow(style: .hard, dx: 6, dy: 6, blur: 0, opacity: 1)
}

/// 字：字族描述（字級階仍走 `Tokens.FontSize`，換皮只切字族與字重感）。
struct SkinType: Equatable, Sendable {
    enum Family: Sendable { case condensed, systemHeavy }
    var displayFamily: Family
    static let instrument = SkinType(displayFamily: .condensed)
    static let brutal = SkinType(displayFamily: .systemHeavy)
}

/// 動：動效與鍵帽行程（springy＝spring＋鍵帽下沉；snappy＝瞬發＋按下右下推）。
struct SkinMotion: Equatable, Sendable {
    var keyTravel: CGFloat
    var instant: Bool
    static let springy = SkinMotion(keyTravel: Tokens.keyTravel, instant: false)
    static let snappy = SkinMotion(keyTravel: 3, instant: true)
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
    // === 換皮新增 · 語義色（additive；舊皮也填，值可沿用既有調性） ===
    let ink: Color          // 絕對黑：硬陰影／粗邊框
    let dangerDeep: Color   // 危險鍵側面（收編 Keycap 繞過 hex）
    let dangerInk: Color    // 危險鍵上的字
    let semSystem: Color    // 系統藍
    let semDefinition: Color// 定義綠
    let semConcept: Color   // 理念琥珀
    let semMarket: Color    // 市場酒紅
    let semTech: Color      // 技術紫
    let userBubble: Color   // 使用者氣泡
    // === 換皮新增 · 形/影/字/動（var＋預設，舊常數免逐欄填寫） ===
    var metrics: SkinMetrics = .instrument
    var shadow: SkinShadow = .soft
    var type: SkinType = .instrument
    var motion: SkinMotion = .springy
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
        scrim: Color(hex: 0x080806, alpha: 0.42),
        ink: Color(hex: 0x000000),
        dangerDeep: Color(hex: 0xA03000),
        dangerInk: Color(hex: 0xFFF2EF),
        semSystem: Color(hex: 0x5CC8FF),
        semDefinition: Color(hex: 0x54D62C),
        semConcept: Color(hex: 0xFFB000),
        semMarket: Color(hex: 0xFF5A47),
        semTech: Color(hex: 0xB89CFF),
        userBubble: Color(hex: 0xFF4D00)
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
        scrim: Color(hex: 0x3C3830, alpha: 0.30),
        ink: Color(hex: 0x000000),
        dangerDeep: Color(hex: 0x9C2E00),
        dangerInk: Color(hex: 0xFFF4EC),
        semSystem: Color(hex: 0x2E8FCF),
        semDefinition: Color(hex: 0x2FA414),
        semConcept: Color(hex: 0xD98F00),
        semMarket: Color(hex: 0xC8321F),
        semTech: Color(hex: 0x7A5CCF),
        userBubble: Color(hex: 0xE84200)
    )

    /// 主題 C：野獸派（Neo-Brutalism）—— 黃底黑邊、直角硬影、五色語義分區。
    /// 視覺基準：`docs/mockups/neo-brutalism-allscreens.html`。
    static let brutalism = Palette(
        bg: Color(hex: 0xFFE14D),          // 機殼底黃
        panel: Color(hex: 0xFFFFFF),       // 白卡
        panel2: Color(hex: 0xFFFFFF),
        recess: Color(hex: 0xF3F1E2),      // 凹槽（米白）
        line: Color(hex: 0x000000),        // 黑折線
        lineStrong: Color(hex: 0x000000),  // 黑結構邊
        print: Color(hex: 0x000000),       // 黑主文字
        print2: Color(hex: 0x5A5A5A),      // 次級
        print3: Color(hex: 0x6B6B6B),      // 微印刷／placeholder
        orange: Color(hex: 0xFFB000),      // 主強調（琥珀）
        orangeDeep: Color(hex: 0xC77A00),
        orangeDim: Color(hex: 0xFFB000, alpha: 0.18),
        orangeInk: Color(hex: 0x000000),
        ledGreen: Color(hex: 0x4AF2C8),
        ledAmber: Color(hex: 0xFFB000),
        ledRed: Color(hex: 0xFF5C8A),
        danger: Color(hex: 0xFF5C8A),
        scrim: Color(hex: 0x000000, alpha: 0.50),
        ink: Color(hex: 0x000000),
        dangerDeep: Color(hex: 0xC23360),
        dangerInk: Color(hex: 0xFFFFFF),
        semSystem: Color(hex: 0x5CC8FF),       // 系統藍
        semDefinition: Color(hex: 0x4AF2C8),   // 定義綠
        semConcept: Color(hex: 0xFFB000),      // 理念琥珀
        semMarket: Color(hex: 0xFF5C8A),       // 市場酒紅
        semTech: Color(hex: 0xB89CFF),         // 技術紫
        userBubble: Color(hex: 0x7FD4FF),      // 使用者氣泡青藍
        metrics: .brutal,
        shadow: .hard,
        type: .brutal,
        motion: .snappy
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

// MARK: - Skin 形狀便利（畫面層收斂硬編碼圓角／膠囊用）

extension Palette {
    /// 是否硬皮（野獸派：直角＋硬影）。
    var isHard: Bool { shadow.style == .hard }
    /// 圓角解析：硬皮一律 0，否則用給定基準值。
    func radius(_ base: CGFloat) -> CGFloat { isHard ? 0 : base }
    /// 膠囊類形狀：硬皮方角矩形、軟皮膠囊（用於 pill / tag / 圓形圖標鈕）。
    var pillShape: AnyShape { isHard ? AnyShape(Rectangle()) : AnyShape(Capsule()) }
    /// 圓角矩形形狀：硬皮直角、軟皮給定圓角。
    func roundShape(_ base: CGFloat) -> AnyShape {
        isHard ? AnyShape(Rectangle()) : AnyShape(RoundedRectangle(cornerRadius: base, style: .continuous))
    }
}

// MARK: - 硬位移陰影原語（野獸派）

extension View {
    /// 野獸派硬位移陰影：視圖正後方疊一塊同形實心色塊，位移 (dx,dy)、零模糊。
    /// 任意 `Shape` 版（卡片用 `Rectangle()`／圓角矩形皆可）。
    func hardShadow(_ shape: some Shape, dx: CGFloat = 6, dy: CGFloat = 6, color: Color = .black) -> some View {
        background(shape.fill(color).offset(x: dx, y: dy))
    }

    /// 預設方角硬影。
    func hardShadow(dx: CGFloat = 6, dy: CGFloat = 6, color: Color = .black) -> some View {
        hardShadow(Rectangle(), dx: dx, dy: dy, color: color)
    }

    /// 表面陰影：hard→實心位移塊（墨色）；soft→原生柔光（預設值＝舊皮原樣，零視覺回歸）。
    @ViewBuilder
    func cardShadow(_ palette: Palette, shape: some Shape,
                    softColor: Color = .black.opacity(0.28), softRadius: CGFloat = 7, softY: CGFloat = 4) -> some View {
        switch palette.shadow.style {
        case .hard: hardShadow(shape, dx: palette.shadow.dx, dy: palette.shadow.dy, color: palette.ink)
        case .soft: shadow(color: softColor, radius: softRadius, y: softY)
        }
    }
}
