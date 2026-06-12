import SwiftUI

// ============================================================
// P0 · 登入 —— 佈局 1:1 對齊 web（置中：logo 方塊／標題／副標／
// Apple 登入鍵／細說明）；工業橘皮不變。真 Sign in with Apple 待接。
// ============================================================

struct LoginScreen: View {

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            // logo 方塊（web .logo：64×64 圓角漸層；工業＝橘缺角磚 + B）
            Text(verbatim: "B")
                .font(Tokens.Fonts.display(30, weight: .heavy))
                .foregroundStyle(palette.orangeInk)
                .frame(width: 64, height: 64)
                .background(NotchedRectangle(notch: 10).fill(palette.orange))

            // 標題
            Text(verbatim: "BrainStrom")
                .font(Tokens.Fonts.display(34, weight: .heavy))
                .foregroundStyle(palette.print)

            // 副標（web 同文，max 240）
            Text(String(localized: "氛圍開發筆記 · 自然語言，就是程式"))
                .font(Tokens.Fonts.body(14))
                .foregroundStyle(palette.print2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            // Apple 登入鍵（web 240 寬黑鍵；工業＝appleBlack 鍵帽）
            Button {
                Haptics.press()
                isSigningIn = true
                Task {
                    await root.signIn()
                    isSigningIn = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isSigningIn {
                        ProgressView().tint(.white)
                        Text(String(localized: "登入中…"))
                    } else {
                        Image(systemName: "apple.logo")
                        Text(String(localized: "使用 Apple 登入"))
                    }
                }
                .font(Tokens.Fonts.body(15.5, weight: .semibold))
                .frame(width: 240, height: 50)
            }
            .buttonStyle(.keycap(.appleBlack, cornerRadius: 12))
            .accessibilityIdentifier("login.apple")
            .disabled(isSigningIn)
            .opacity(isSigningIn ? 0.7 : 1)

            // 細說明（web faint，max 230）
            Text(String(localized: "收集 email 供登入、儲存你的筆記（示範用 dev 登入）"))
                .font(Tokens.Fonts.body(11))
                .foregroundStyle(palette.print3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(palette.bg)
    }
}

#Preview("P0 登入") {
    LoginScreen()
        .environment(CompositionRoot())
        .environment(\.palette, .matteBlack)
}
