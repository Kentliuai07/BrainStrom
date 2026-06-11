import SwiftUI

// ============================================================
// 缺角矩形 —— BrainStrom 品牌簽名（45° 切角）
// ============================================================

/// 一個角被 45° 切掉的圓角矩形。
/// 卡片：右上切 `Tokens.Notch.card`；模組直條：左上切 `Tokens.Notch.rail`。
struct NotchedRectangle: InsettableShape {

    enum NotchCorner: Sendable {
        case topTrailing
        case topLeading
    }

    var notch: CGFloat = Tokens.Notch.card
    var corner: NotchCorner = .topTrailing
    var cornerRadius: CGFloat = Tokens.Radius.card
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> NotchedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let n = min(notch, min(rect.width, rect.height))

        switch corner {
        case .topTrailing:
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - n, y: rect.minY))                  // 上邊 → 缺角起點
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + n))                  // 45° 切角
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))                  // 右邊
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))                  // 下邊
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))                  // 左邊
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        case .topLeading:
            path.move(to: CGPoint(x: rect.minX + n, y: rect.minY))                     // 缺角終點
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))                  // 上邊
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))                  // 右邊
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))                  // 下邊
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + n))                  // 左邊 → 缺角
            path.addLine(to: CGPoint(x: rect.minX + n, y: rect.minY))                  // 45° 切角
        }

        path.closeSubpath()
        return path
    }
}

#Preview("缺角簽名", traits: .sizeThatFitsLayout) {
    HStack(spacing: 20) {
        NotchedRectangle()
            .fill(Palette.matteBlack.panel)
            .overlay(NotchedRectangle().strokeBorder(Palette.matteBlack.lineStrong, lineWidth: 1))
            .frame(width: 140, height: 90)
        NotchedRectangle(notch: Tokens.Notch.rail, corner: .topLeading, cornerRadius: 0)
            .fill(Palette.matteBlack.panel)
            .frame(width: 70, height: 90)
    }
    .padding(30)
    .background(Palette.matteBlack.bg)
}
