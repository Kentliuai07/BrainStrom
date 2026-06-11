import SwiftUI

// ============================================================
// 鍵帽按鈕 —— 遊戲趣味的核心：2.5pt 實體行程
// ============================================================

/// 機械鍵帽 ButtonStyle：上亮下暗、按壓下沉。
/// 使用：`Button { Haptics.press(); … } label: { … }.buttonStyle(.keycap(.orange))`
struct KeycapButtonStyle: ButtonStyle {

    enum Kind: Sendable {
        case neutral    // 一般功能鍵
        case orange     // AI／關鍵操作（TE 橘）
        case danger     // 危險操作（紅）
        case appleBlack // Sign in with Apple 專用黑鍵
    }

    var kind: Kind = .neutral
    var cornerRadius: CGFloat = Tokens.Radius.key

    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            // 底座（固定不動，露出行程厚度）
            configuration.label
                .hidden()
                .background(shape.fill(sideColor))
                .offset(y: Tokens.keyTravel)

            // 鍵帽面（按壓下沉）
            configuration.label
                .foregroundStyle(inkColor)
                .background(shape.fill(faceColor))
                .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
                .overlay(alignment: .top) {
                    // 上緣受光
                    shape.strokeBorder(highlightColor, lineWidth: 1)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                }
                .offset(y: pressed ? Tokens.keyTravel : 0)
        }
        .animation(Motion.key, value: pressed)
    }

    private var faceColor: Color {
        switch kind {
        case .neutral: palette.panel2
        case .orange: palette.orange
        case .danger: palette.danger
        case .appleBlack: .black
        }
    }

    private var sideColor: Color {
        switch kind {
        case .neutral: palette.lineStrong
        case .orange: palette.orangeDeep
        case .danger: Color(hex: 0x7A1A0E)
        case .appleBlack: palette.lineStrong
        }
    }

    private var inkColor: Color {
        switch kind {
        case .neutral: palette.print
        case .orange: palette.orangeInk
        case .danger: Color(hex: 0xFFF2EF)
        case .appleBlack: .white
        }
    }

    private var borderColor: Color {
        switch kind {
        case .neutral: palette.lineStrong
        case .orange: palette.orange
        case .danger: palette.danger
        case .appleBlack: .black
        }
    }

    private var highlightColor: Color {
        switch kind {
        case .orange: Color(hex: 0xFFC8A0, alpha: 0.35)
        default: Color.white.opacity(0.10)
        }
    }
}

extension ButtonStyle where Self == KeycapButtonStyle {
    /// 鍵帽樣式便利入口。
    static func keycap(_ kind: KeycapButtonStyle.Kind = .neutral,
                       cornerRadius: CGFloat = Tokens.Radius.key) -> KeycapButtonStyle {
        KeycapButtonStyle(kind: kind, cornerRadius: cornerRadius)
    }
}

#Preview("鍵帽", traits: .sizeThatFitsLayout) {
    HStack(spacing: 16) {
        Button {} label: {
            VStack(spacing: 2) {
                Text("✦").font(.system(size: 17))
                Text("OPTIMIZE").font(Tokens.Fonts.mono(7.5, weight: .medium)).kerning(1)
            }
            .frame(width: 56, height: 52)
        }
        .buttonStyle(.keycap(.orange))

        Button {} label: {
            Text("取消").font(Tokens.Fonts.body(15, weight: .semibold))
                .frame(width: 100, height: 46)
        }
        .buttonStyle(.keycap())

        Button {} label: {
            Text("驗證並刪除").font(Tokens.Fonts.body(15, weight: .semibold))
                .frame(width: 120, height: 46)
        }
        .buttonStyle(.keycap(.danger))
    }
    .padding(30)
    .background(Palette.matteBlack.bg)
    .environment(\.palette, .matteBlack)
}
