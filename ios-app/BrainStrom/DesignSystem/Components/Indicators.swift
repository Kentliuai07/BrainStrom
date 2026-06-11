import SwiftUI

// ============================================================
// 指示元件：LED 燈、LED 段條、警示斜紋
// ============================================================

/// 單顆 LED。語義：綠=運行/完成、琥珀=警示/PRO、紅=危險、橘=AI。
struct LEDIndicator: View {
    enum Mode: Sendable {
        case steady
        case pulsing   // 呼吸（Motion.ledPulse 週期）
        case off
    }

    var color: Color
    var mode: Mode = .steady
    var size: CGFloat = 7

    @Environment(\.palette) private var palette

    var body: some View {
        switch mode {
        case .off:
            Circle()
                .fill(palette.panel2)
                .overlay(Circle().strokeBorder(palette.lineStrong, lineWidth: 1))
                .frame(width: size, height: size)
        case .steady:
            lit.frame(width: size, height: size)
        case .pulsing:
            lit
                .frame(width: size, height: size)
                .phaseAnimator([1.0, 0.35]) { view, phase in
                    view.opacity(phase)
                } animation: { _ in
                    .easeInOut(duration: Motion.ledPulse / 2)
                }
        }
    }

    private var lit: some View {
        Circle()
            .fill(color)
            .shadow(color: color.opacity(0.8), radius: 3)
    }
}

/// 10 段（可調）LED 進度條 —— 進度的硬體表達。
struct LEDBarGauge: View {
    var filled: Int
    var total: Int = 10
    var color: Color
    var segmentHeight: CGFloat = 9

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? color : palette.panel2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(index < filled ? color : palette.line, lineWidth: 1)
                    )
                    .shadow(color: index < filled ? color.opacity(0.5) : .clear, radius: 2.5)
                    .frame(height: segmentHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "進度 \(filled) / \(total)")))
    }
}

/// 45° 警示斜紋（釘選＝橘、危險區＝紅）。
struct HazardStripes: View {
    var color: Color
    var stripeWidth: CGFloat = 5
    var gap: CGFloat = 5

    var body: some View {
        Canvas { context, size in
            let period = stripeWidth + gap
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: stripeWidth)
                x += period * 1.41421
            }
        }
        .opacity(0.85)
        .accessibilityHidden(true)
    }
}

#Preview("指示元件", traits: .sizeThatFitsLayout) {
    let p = Palette.matteBlack
    VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 14) {
            LEDIndicator(color: p.ledGreen, mode: .pulsing)
            LEDIndicator(color: p.ledAmber)
            LEDIndicator(color: p.ledRed)
            LEDIndicator(color: p.orange, mode: .pulsing)
            LEDIndicator(color: .clear, mode: .off)
        }
        LEDBarGauge(filled: 6, color: p.ledGreen)
        LEDBarGauge(filled: 3, color: p.orange)
        HazardStripes(color: p.orange).frame(width: 120, height: 9)
        HazardStripes(color: p.ledRed).frame(width: 120, height: 9)
    }
    .padding(30)
    .background(p.bg)
    .environment(\.palette, p)
}
