import SwiftUI

// ============================================================
// 面板元件：硬體卡、模板印刷標、銘板抬頭、機身印刷
// ============================================================

/// 硬體模組卡容器修飾器：面板底＋結構邊＋缺角簽名＋上緣受光。
struct HardwareCardModifier: ViewModifier {
    var notch: CGFloat = Tokens.Notch.card

    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let shape = NotchedRectangle(notch: notch)
        content
            .background(shape.fill(palette.panel))
            .overlay(shape.strokeBorder(palette.lineStrong, lineWidth: 1))
            .overlay(alignment: .top) {
                shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
    }
}

extension View {
    /// 套上硬體模組卡外觀。
    func hardwareCard(notch: CGFloat = Tokens.Notch.card) -> some View {
        modifier(HardwareCardModifier(notch: notch))
    }
}

/// 模板印刷分區標：`DOCUMENT ───────`。
struct StencilLabel: View {
    let text: String
    var trailingRule = true

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(Tokens.Fonts.mono(Tokens.FontSize.stencil, weight: .semibold))
                .kerning(Tokens.Kerning.stencil)
                .foregroundStyle(palette.print3)
                .textCase(.uppercase)
            if trailingRule {
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 銘板抬頭：`MOD-01 觀測進度 ●●`（編號＋名稱＋狀態 LED）。
struct Nameplate<Accessory: View>: View {
    let id: String
    let name: String
    @ViewBuilder var accessory: Accessory

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(id)
                .font(Tokens.Fonts.mono(8.5, weight: .medium))
                .kerning(2.5)
                .foregroundStyle(palette.print3)
                .textCase(.uppercase)
                .accessibilityHidden(true)
            Text(name)
                .font(Tokens.Fonts.body(12, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(palette.print)
            Spacer(minLength: 0)
            accessory
        }
    }
}

extension Nameplate where Accessory == EmptyView {
    init(id: String, name: String) {
        self.init(id: id, name: name) { EmptyView() }
    }
}

/// 機身印刷腳註：`BRAINSTROM ◦ NOTE OS 1.0`。
struct PrintFootnote: View {
    let parts: [String]

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Circle()
                        .strokeBorder(palette.print3, lineWidth: 1)
                        .frame(width: 5, height: 5)
                }
                Text(part)
                    .font(Tokens.Fonts.mono(8, weight: .medium))
                    .kerning(2.4)
                    .foregroundStyle(palette.print3)
                    .textCase(.uppercase)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("面板元件", traits: .sizeThatFitsLayout) {
    let p = Palette.matteBlack
    VStack(alignment: .leading, spacing: 20) {
        StencilLabel(text: "Document")
        VStack(alignment: .leading, spacing: 10) {
            Nameplate(id: "MOD-01", name: "觀測進度") {
                LEDIndicator(color: p.ledGreen, mode: .pulsing)
            }
            LEDBarGauge(filled: 6, color: p.ledGreen)
        }
        .padding(16)
        .hardwareCard()
        PrintFootnote(parts: ["Brainstrom", "Note OS 1.0"])
            .frame(maxWidth: .infinity)
    }
    .padding(24)
    .frame(width: 360)
    .background(p.bg)
    .environment(\.palette, p)
}
