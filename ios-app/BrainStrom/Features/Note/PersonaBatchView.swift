import SwiftUI

// ============================================================
// 第3模式 · 批量生成定位卡 画面
// loading：流式进度+可取消 ／ browsing：单张大卡左右切换+单卡重生+选这个
// ============================================================

struct PersonaBatchView: View {

    let appName: String
    let oneLiner: String
    let country: String
    let onSelect: (PersonaCard) -> Void
    let onCancel: () -> Void

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette
    @State private var vm: PersonaBatchViewModel?

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            if let vm {
                switch vm.phase {
                case .loading: loadingView(vm)
                case .failed: failedView(vm)
                case .browsing: browsingView(vm)
                }
            } else {
                ProgressView().tint(palette.orange)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil {
                let model = PersonaBatchViewModel(ai: root.ai)
                vm = model
                model.start(appName: appName, oneLiner: oneLiner, country: country)
            }
        }
        .onDisappear { vm?.cancel() }
    }

    // MARK: - loading（流式过程）

    private func loadingView(_ vm: PersonaBatchViewModel) -> some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().controlSize(.large).tint(palette.orange)
            Text(vm.progress.isEmpty ? String(localized: "準備中…") : vm.progress)
                .font(Tokens.Fonts.body(14, weight: .semibold)).foregroundStyle(palette.print)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
                .id(vm.progress)
                .transition(.opacity)
            Text(String(localized: "先查真實市場，再幫你生 4 種定位（約需 1 分鐘）"))
                .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
            Spacer()
            Button { vm.cancel(); onCancel() } label: {
                Text(String(localized: "取消")).font(Tokens.Fonts.body(14, weight: .semibold))
                    .frame(width: 140, height: 46)
            }
            .buttonStyle(.keycap())
            .accessibilityIdentifier("persona.cancel")
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: vm.progress)
    }

    // MARK: - failed

    private func failedView(_ vm: PersonaBatchViewModel) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(verbatim: "⚠").font(.system(size: 30)).foregroundStyle(palette.print3)
            Text(vm.errorMessage ?? String(localized: "生成失敗")).font(Tokens.Fonts.body(14)).foregroundStyle(palette.print2)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            HStack(spacing: 12) {
                Button { onCancel() } label: { Text(String(localized: "返回")).frame(width: 110, height: 46) }
                    .buttonStyle(.keycap())
                Button { vm.start(appName: appName, oneLiner: oneLiner, country: country) } label: {
                    Text(String(localized: "重試")).frame(width: 110, height: 46)
                }
                .buttonStyle(.keycap(.orange))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - browsing（单张大卡 + 切换）

    private func browsingView(_ vm: PersonaBatchViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm)
            TabView(selection: Binding(get: { vm.current }, set: { vm.current = $0 })) {
                ForEach(0..<vm.cards.count, id: \.self) { i in
                    cardPage(vm, index: i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button { Haptics.press(); onSelect(vm.cards[vm.current]) } label: {
                Text(String(localized: "✓ 選這個，開始微調"))
                    .font(Tokens.Fonts.body(15, weight: .bold)).frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(.keycap(.orange))
            .disabled(!vm.ready[vm.current])
            .opacity(vm.ready[vm.current] ? 1 : 0.5)
            .accessibilityIdentifier("persona.select")
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    private func topBar(_ vm: PersonaBatchView.VM) -> some View {
        HStack {
            Button { vm.cancel(); onCancel() } label: {
                Text(String(localized: "‹ 取消")).font(Tokens.Fonts.body(15, weight: .semibold)).foregroundStyle(palette.orange)
            }
            .accessibilityIdentifier("persona.back")
            Spacer()
            Text(String(localized: "定位 \(vm.current + 1) / \(vm.cards.count)"))
                .font(Tokens.Fonts.mono(12, weight: .bold)).foregroundStyle(palette.print2)
            Spacer()
            Button { Haptics.tap(); vm.regenerate(vm.current) } label: {
                HStack(spacing: 4) {
                    if vm.regeneratingIndex == vm.current { ProgressView().controlSize(.mini).tint(palette.orange) }
                    Text(String(localized: "🔄 重生")).font(Tokens.Fonts.body(13, weight: .semibold)).foregroundStyle(palette.orange)
                }
            }
            .disabled(vm.regeneratingIndex != nil || !vm.ready[vm.current])
            .accessibilityIdentifier("persona.regenerate")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    typealias VM = PersonaBatchViewModel

    @ViewBuilder
    private func cardPage(_ vm: PersonaBatchViewModel, index i: Int) -> some View {
        let ready = vm.ready[i]
        let card = vm.cards[i]
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if ready {
                    Text(card.tagline.isEmpty ? card.oneLiner : card.tagline)
                        .font(Tokens.Fonts.display(20, weight: .heavy)).foregroundStyle(palette.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    field(String(localized: "一句話"), card.oneLiner)
                    field(String(localized: "目標用戶"), card.targetUser)
                    field(String(localized: "解決痛點"), card.painPoint)
                    field(String(localized: "核心價值"), card.coreValue)
                    field(String(localized: "核心功能"), card.coreFeatures)
                    field(String(localized: "市場策略"), card.marketStrategy)
                    field(String(localized: "商業模式"), card.businessModel)
                    HStack(spacing: 6) {
                        Text(verbatim: "🛠").font(.system(size: 12))
                        Text(String(localized: "技術棧：AI 推測，挑中後再由你確認"))
                            .font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
                    }
                    .padding(.top, 4)
                } else {
                    // 串流中：打字机逐字
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(palette.orange)
                        Text(String(localized: "生成中…")).font(Tokens.Fonts.body(12)).foregroundStyle(palette.print3)
                    }
                    Text(i == vm.current ? vm.typewriter.shown : vm.drafts[i])
                        .font(Tokens.Fonts.body(15)).foregroundStyle(palette.print)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hardwareCard()
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Tokens.Fonts.mono(10, weight: .bold)).kerning(1).foregroundStyle(palette.print3)
            Text(value.isEmpty ? "—" : value).font(Tokens.Fonts.body(14)).foregroundStyle(palette.print)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
