import SwiftUI

// ============================================================
// 控制元件：撥動開關、輸入凹槽
// ============================================================

/// 機械撥動開關 ToggleStyle —— 待辦、AI 選項的標準控制。
/// 使用：`Toggle("分主題", isOn: $on).toggleStyle(.hardware)`
struct HardwareToggleStyle: ToggleStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            Haptics.selection()
        } label: {
            HStack(spacing: Tokens.Spacing.s3) {
                track(isOn: configuration.isOn)
                configuration.label
                    .font(Tokens.Fonts.body(16.5))
                    .foregroundStyle(configuration.isOn ? palette.print2 : palette.print)
                    .strikethrough(configuration.isOn, color: palette.print3)
            }
        }
        .buttonStyle(.plain)
        .animation(Motion.key, value: configuration.isOn)
    }

    private func track(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isOn ? palette.orangeDim : palette.panel2)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isOn ? palette.orange : palette.lineStrong, lineWidth: 1)
            )
            .overlay(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(isOn ? palette.orange : palette.print2)
                    .frame(width: 13, height: 13)
                    .padding(2.5)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .frame(width: 34, height: 19)
    }
}

extension ToggleStyle where Self == HardwareToggleStyle {
    /// 撥動開關便利入口。
    static var hardware: HardwareToggleStyle { HardwareToggleStyle() }
}

/// 輸入凹槽 —— 「輸入是插槽、AI 是按鍵」的硬體隱喻。
struct SlotField<Content: View>: View {
    var height: CGFloat = 46
    @ViewBuilder var content: Content

    @Environment(\.palette) private var palette

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.input)
                    .fill(palette.recess)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 2)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.input))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.input)
                    .strokeBorder(palette.line, lineWidth: 1)
            )
    }
}

#Preview("控制元件", traits: .sizeThatFitsLayout) {
    @Previewable @State var done = true
    @Previewable @State var todo = false
    let p = Palette.matteBlack
    VStack(alignment: .leading, spacing: 18) {
        Toggle("借紅外線溫度計（已跟實驗室登記）", isOn: $done).toggleStyle(.hardware)
        Toggle("畫出三條觀測路線的地圖", isOn: $todo).toggleStyle(.hardware)
        SlotField {
            Text("搜尋，或直接問 AI…")
                .font(Tokens.Fonts.body(14.5))
                .foregroundStyle(p.print3)
                .padding(.horizontal, 14)
        }
    }
    .padding(24)
    .frame(width: 360)
    .background(p.bg)
    .environment(\.palette, p)
}
