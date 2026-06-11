import SwiftUI

// ============================================================
// P3 · 設定 —— 佈局 1:1 對齊 web settings()：
// nav(返回/設定) → 主題seg/帳號/登出 list → AI(點子助攻開關) → 刪除帳號
// 保留工業橘皮；機殼切換沿用 3 款。
// ============================================================

struct SettingsScreen: View {

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var nudgeOn = true
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    accountCard
                    sectionLabel("AI")
                    aiCard
                    deleteButton
                    Text(String(localized: "刪除將立即永久移除你的資料、無法復原（正式版會再要求 Apple 驗證）。"))
                        .font(Tokens.Fonts.body(11))
                        .foregroundStyle(palette.print3)
                        .padding(.top, 8)
                }
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.top, Tokens.Spacing.s4)
                .padding(.bottom, 28)
            }
        }
        .background(palette.bg)
        .navigationBarHidden(true)
        .confirmationDialog(String(localized: "確定刪除帳號？資料將立即永久刪除、無法復原。"),
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(String(localized: "刪除帳號"), role: .destructive) {
                Task {
                    await root.signOut()
                    root.toast.show(String(localized: "帳號已刪除"))
                }
            }
            Button(String(localized: "取消"), role: .cancel) {}
        }
    }

    // MARK: - nav

    private var navBar: some View {
        HStack {
            Button { Haptics.tap(); dismiss() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "返回")).font(Tokens.Fonts.body(15, weight: .semibold))
                }
                .foregroundStyle(palette.orange)
            }
            Spacer()
            Text(String(localized: "設定")).font(Tokens.Fonts.body(15, weight: .bold)).foregroundStyle(palette.print)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(palette.panel.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }

    // MARK: - 帳號 list 卡

    private var accountCard: some View {
        VStack(spacing: 0) {
            // 主題（web seg：黑曜石|親和；此處沿用 3 款機殼）
            row {
                Text(String(localized: "主題")).font(Tokens.Fonts.body(15)).foregroundStyle(palette.print)
                Spacer()
                skinSeg
            }
            divider
            // 帳號 email
            row {
                Text(String(localized: "帳號")).font(Tokens.Fonts.body(15)).foregroundStyle(palette.print)
                Spacer()
                Text(accountEmail).font(Tokens.Fonts.body(14)).foregroundStyle(palette.print2)
            }
            divider
            // 登出（整列可點）
            Button { Haptics.tap(); Task { await root.signOut() } } label: {
                row {
                    Text(String(localized: "登出")).font(Tokens.Fonts.body(15, weight: .semibold)).foregroundStyle(palette.orange)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .hardwareCard()
    }

    private var skinSeg: some View {
        HStack(spacing: 2) {
            ForEach(MachineSkin.allCases, id: \.self) { skin in
                Button {
                    Haptics.selection(); root.theme.skin = skin
                } label: {
                    Text(skin.displayName)
                        .font(Tokens.Fonts.body(11, weight: .bold))
                        .foregroundStyle(root.theme.skin == skin ? palette.orangeInk : palette.print2)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(root.theme.skin == skin ? palette.orange : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9).fill(palette.recess)
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(palette.line, lineWidth: 1)))
    }

    // MARK: - AI 區塊

    private var aiCard: some View {
        VStack(spacing: 0) {
            row {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "點子助攻")).font(Tokens.Fonts.body(15)).foregroundStyle(palette.print)
                    Text(String(localized: "取名後浮現「⚡ 讓 AI 教練看看」膠囊"))
                        .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
                }
                Spacer()
                Toggle("", isOn: $nudgeOn)
                    .labelsHidden()
                    .toggleStyle(.hardware)
                    .onChange(of: nudgeOn) { _, on in
                        root.toast.show(on ? String(localized: "已開啟點子助攻") : String(localized: "已關閉點子助攻"))
                    }
            }
        }
        .hardwareCard()
    }

    // MARK: - 刪除帳號

    private var deleteButton: some View {
        Button {
            Haptics.warning(); confirmDelete = true
        } label: {
            Text(String(localized: "刪除帳號"))
                .font(Tokens.Fonts.body(15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.keycap(.danger, cornerRadius: 12))
        .padding(.top, 18)
    }

    // MARK: - 小積木

    private var accountEmail: String {
        if case let .signedIn(account) = root.session { return account.email ?? "" }
        return ""
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.mono(11, weight: .bold))
            .kerning(1.6)
            .foregroundStyle(palette.print3)
            .padding(.leading, 2)
            .padding(.top, 16).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) { content() }
            .padding(14)
    }

    private var divider: some View {
        Rectangle().fill(palette.line).frame(height: 1).padding(.horizontal, 14)
    }
}

#Preview("P3 設定") {
    NavigationStack {
        SettingsScreen()
    }
    .environment(CompositionRoot())
    .environment(\.palette, .matteBlack)
}
