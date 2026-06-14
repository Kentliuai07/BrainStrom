import SwiftUI

// ============================================================
// P1 · 首頁「我的系統」—— 佈局 1:1 對齊 web home()：
// 標題列（我的系统 / BrainStrom + 齒輪 + 加號）→ banner → 系統卡清單
// （web 首頁沒有搜尋槽，已移除）。工業橘皮不變、不接後端。
// ============================================================

/// 導航路由（首頁推到設定 / 專案首頁）。
/// 階段三起改為唯一路由源——點系統卡推 `.systemDetail`（三分頁容器），不再直推 UUID。
/// 建專案的兩條路（弹窗②選）。
enum CreationMode: Hashable { case kickoff, notes }

enum HomeRoute: Hashable {
    case settings
    case systemDetail(id: UUID, mode: CreationMode)
    case noteDetail(noteID: UUID)
    case personaBatch(name: String, oneLiner: String, country: String)   // 第3模式：批量生成定位卡
}

struct HomeScreen: View {

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var path = NavigationPath()
    @State private var systems: [NoteSystem] = []
    @State private var loaded = false
    @State private var loadFailed = false
    @State private var showCreateSheet = false
    @State private var newProjectName = ""
    @State private var newOneLiner = ""
    @State private var countryStore = CountryStore()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    banner
                    systemList
                }
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.top, Tokens.Spacing.s4)
                .padding(.bottom, 28)
            }
            .background(palette.bg)
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .settings: SettingsScreen()
                case .systemDetail(let id, let mode):
                    SystemDetailScreen(systemID: id, path: $path, mode: mode)
                case .noteDetail(let id): NoteDetailScreen(noteID: id)
                case .personaBatch(let name, let oneLiner, let country):
                    PersonaBatchView(appName: name, oneLiner: oneLiner, country: country,
                                     onSelect: { card in selectPersona(card, name: name) },
                                     onCancel: { if !path.isEmpty { path.removeLast() } })
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: path) { _, new in
            if new.isEmpty { reload() }  // 從筆記/設定返回 → 刷新清單
        }
        // 建專案 sheet：①名稱 ②一句話作用 ③目標國家 ④三種開始方式
        .sheet(isPresented: $showCreateSheet) {
            CreationSheet(name: $newProjectName, oneLiner: $newOneLiner, country: countryStore,
                          onMode: { mode in showCreateSheet = false; createProject(mode: mode) },
                          onPersona: { showCreateSheet = false; startPersona() },
                          onCancel: { showCreateSheet = false })
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - 標題列（web .row：左標題 + 齒輪 + 加號）

    private var header: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "我的系統"))
                    .font(Tokens.Fonts.body(12))
                    .foregroundStyle(palette.print3)
                Text(verbatim: "BrainStrom")
                    .font(Tokens.Fonts.display(30, weight: .heavy))
                    .foregroundStyle(palette.print)
            }
            Spacer()
            circleIcon(system: "gearshape", accent: false) {
                Haptics.tap()
                path.append(HomeRoute.settings)
            }
            .accessibilityIdentifier("home.settings")
            circleIcon(system: "plus", accent: true) {
                Haptics.press()
                newProjectName = ""; newOneLiner = ""; showCreateSheet = true
            }
            .accessibilityIdentifier("home.create")
        }
        .padding(.bottom, Tokens.Spacing.s4)
    }

    /// 圓形圖標鈕（web .iconbtn / .iconbtn.accent）。野獸派轉方鈕＋黑邊。
    private func circleIcon(system: String, accent: Bool, action: @escaping () -> Void) -> some View {
        let shape = palette.pillShape
        let stroke = palette.isHard ? palette.ink : (accent ? palette.orange.opacity(0.5) : palette.line)
        return Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent ? palette.orange : palette.print2)
                .frame(width: 44, height: 44)
                .background(shape.fill(palette.panel))
                .overlay(shape.stroke(stroke, lineWidth: palette.metrics.border))
        }
        .buttonStyle(.plain)
    }

    // MARK: - banner（web .banner）

    private var banner: some View {
        HStack(spacing: 8) {
            Text(verbatim: "✦")
                .font(.system(size: 14))
                .foregroundStyle(palette.orange)
            Text(String(localized: "＋ 建專案 → 輸入名稱或靈感 → AI 引導你想清楚痛點/用戶/功能，邊聊邊填身份證"))
                .font(Tokens.Fonts.body(12))
                .foregroundStyle(palette.print)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input))
                .fill(palette.orangeDim)
                .overlay(RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input))
                    .strokeBorder(palette.isHard ? palette.ink : palette.orange.opacity(0.26), lineWidth: palette.metrics.border))
        )
        .padding(.bottom, Tokens.Spacing.s3)
    }

    // MARK: - 系統清單 / 空態 / 載入態

    @ViewBuilder
    private var systemList: some View {
        if !loaded {
            Text(String(localized: "載入中…"))
                .font(Tokens.Fonts.body(14))
                .foregroundStyle(palette.print2)
                .padding(.vertical, 20)
        } else if loadFailed {
            VStack(spacing: 12) {
                Text(String(localized: "載入失敗"))
                    .font(Tokens.Fonts.body(14)).foregroundStyle(palette.print2)
                Button { Haptics.tap(); reload() } label: {
                    Text(String(localized: "重試"))
                        .font(Tokens.Fonts.body(14, weight: .semibold))
                        .frame(width: 120, height: 44)
                }
                .buttonStyle(.keycap())
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else if systems.isEmpty {
            emptyRack
        } else {
            VStack(spacing: 11) {
                ForEach(systems) { system in
                    Button {
                        Haptics.tap()
                        path.append(HomeRoute.systemDetail(id: system.id, mode: .notes))
                    } label: {
                        SystemCardView(system: system)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyRack: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(verbatim: "▦").font(.system(size: 26)).foregroundStyle(palette.print3)
                Text(String(localized: "還沒有系統"))
                    .font(Tokens.Fonts.body(14))
                    .foregroundStyle(palette.print2)
            }
            .frame(width: 170, height: 110)
            .overlay(
                NotchedRectangle(notch: palette.metrics.notchCard, cornerRadius: palette.metrics.radiusCard)
                    .strokeBorder(palette.lineStrong, style: StrokeStyle(lineWidth: palette.isHard ? palette.metrics.border : 1.5, dash: [5, 4]))
            )
            Button {
                Haptics.press()
                newProjectName = ""; newOneLiner = ""; showCreateSheet = true
            } label: {
                Text(String(localized: "建立第一個系統"))
                    .font(Tokens.Fonts.body(14.5, weight: .semibold))
                    .frame(width: 180, height: 46)
            }
            .buttonStyle(.keycap(.orange))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    // MARK: - 資料

    private func reload() {
        guard let repo = root.repository else { systems = []; loaded = true; return }
        do {
            // 階段三：清掉沒有任何筆記的空系統（建了沒寫就走的殘留；在首頁清最安全，不會誤刪正在編輯的）
            for s in (try? repo.systems()) ?? [] where s.noteCount == 0 {
                try? repo.deleteSystem(id: s.id)
            }
            systems = try repo.systems()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        loaded = true
    }

    /// 选模式后 → 原子建系統+主筆記 → 進專案首頁（kickoff→教練自动开场；notes→开发笔记）。
    private func createProject(mode: CreationMode) {
        guard let repository = root.repository else { return }
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? String(localized: "未命名專案") : name
        let seed = newOneLiner.trimmingCharacters(in: .whitespacesAndNewlines)   // 一句话作用 → 写进主笔记给 AI 读
        newProjectName = ""; newOneLiner = ""
        guard let result = try? repository.createSystemWithPrimaryNote(name: title, initialContent: seed) else { return }
        path.append(HomeRoute.systemDetail(id: result.system.id, mode: mode))
    }

    /// 第3模式：进批量生成画面（先搜后生成，挑中才建专案）。
    private func startPersona() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let oneLiner = newOneLiner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !oneLiner.isEmpty else { return }
        path.append(HomeRoute.personaBatch(name: name, oneLiner: oneLiner, country: countryStore.code))
    }

    /// 挑中一张定位 → 原子建系統+主筆记 → 灌身份证 → 取代 persona 路由进系统详情。
    private func selectPersona(_ card: PersonaCard, name: String) {
        guard let repository = root.repository else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = title.isEmpty ? (card.tagline.isEmpty ? String(localized: "未命名專案") : card.tagline) : title
        guard let result = try? repository.createSystemWithPrimaryNote(name: finalName, initialContent: nil) else { return }
        try? repository.updateSystemSpec(systemID: result.system.id, spec: card.toSpec(name: finalName))
        if !path.isEmpty { path.removeLast() }   // 移除 persona 路由
        path.append(HomeRoute.systemDetail(id: result.system.id, mode: .notes))
    }
}

// MARK: - 建專案 Sheet（名稱＋一句話＋目標國家＋三模式）

struct CreationSheet: View {
    @Binding var name: String
    @Binding var oneLiner: String
    @Bindable var country: CountryStore
    let onMode: (CreationMode) -> Void
    let onPersona: () -> Void
    let onCancel: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "新增專案")).font(Tokens.Fonts.display(22, weight: .heavy)).foregroundStyle(palette.print)

                fieldBox(String(localized: "APP 名稱")) {
                    TextField(String(localized: "例如：記帳 App"), text: $name)
                        .accessibilityIdentifier("home.projectNameInput")
                }
                fieldBox(String(localized: "這個 APP 的作用（一句話）")) {
                    TextField(String(localized: "例如：幫人記錄日常開銷"), text: $oneLiner, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("home.oneLinerInput")
                }
                fieldBox(String(localized: "目標國家 / 語言")) {
                    Menu {
                        ForEach(CountryStore.presets) { c in
                            Button(c.label) { country.code = c.code }
                        }
                    } label: {
                        HStack {
                            Text(country.label).foregroundStyle(palette.print)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11)).foregroundStyle(palette.print3)
                        }
                    }
                    .accessibilityIdentifier("home.countryMenu")
                }

                VStack(spacing: 10) {
                    modeButton("🤖 進 AI 引導（建議）", sub: String(localized: "AI 一題一題帶你想清楚"), id: "create.mode.kickoff") { onMode(.kickoff) }
                    modeButton("📝 之後慢慢填，自己寫", sub: String(localized: "你自己寫，AI 在旁偵測幫你記"), id: "create.mode.notes") { onMode(.notes) }
                    modeButton("🪄 直接生成 4 種定位", sub: String(localized: "先查市場，AI 給你 4 種定位挑一個"), id: "create.mode.persona") { onPersona() }
                }
                .padding(.top, 4)

                Button { onCancel() } label: {
                    Text(String(localized: "取消")).font(Tokens.Fonts.body(14, weight: .semibold)).foregroundStyle(palette.print3)
                        .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(palette.bg)
    }

    private func fieldBox(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Tokens.Fonts.mono(10, weight: .bold)).kerning(1).foregroundStyle(palette.print3)
            content()
                .font(Tokens.Fonts.body(15)).foregroundStyle(palette.print)
                .padding(.horizontal, 12).frame(minHeight: 44, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input)).fill(palette.recess)
                    .overlay(RoundedRectangle(cornerRadius: palette.radius(Tokens.Radius.input)).strokeBorder(palette.isHard ? palette.ink : palette.line, lineWidth: palette.metrics.border)))
        }
    }

    private func modeButton(_ title: String, sub: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Tokens.Fonts.body(15, weight: .bold)).foregroundStyle(palette.print)
                Text(sub).font(Tokens.Fonts.body(11)).foregroundStyle(palette.print3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                palette.roundShape(12).fill(palette.panel)
                    .overlay(palette.roundShape(12).stroke(palette.isHard ? palette.ink : palette.line, lineWidth: palette.metrics.border))
            )
            .cardShadow(palette, shape: palette.roundShape(12), softColor: .clear, softRadius: 0, softY: 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// 機架上的系統模組卡（web .syscard：pill + 日期 / 標題 / 摘要）。
struct SystemCardView: View {
    let system: NoteSystem

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                VisibilityPill(visibility: system.visibility)
                Spacer()
                Text(system.updatedAt, format: .dateTime.month(.twoDigits).day(.twoDigits))
                    .font(Tokens.Fonts.mono(10))
                    .foregroundStyle(palette.print3)
            }
            Text(system.name.isEmpty ? String(localized: "未命名系統") : system.name)
                .font(Tokens.Fonts.body(16, weight: .bold))
                .foregroundStyle(palette.print)
                .lineLimit(1)
            Text(system.snippet.isEmpty ? String(localized: "（空白系統，點開開始寫）") : system.snippet)
                .font(Tokens.Fonts.body(12.5))
                .foregroundStyle(palette.print2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !system.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(system.tags, id: \.self) { tag in
                        Text(tag)
                            .font(Tokens.Fonts.mono(9))
                            .foregroundStyle(palette.print3)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(palette.pillShape.stroke(palette.isHard ? palette.ink : palette.line, lineWidth: palette.metrics.border))
                    }
                }
                .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .hardwareCard()
    }
}

/// 私密/公開膠囊（web .pill.priv / .pill.pub）。
struct VisibilityPill: View {
    let visibility: Visibility
    @Environment(\.palette) private var palette

    var body: some View {
        let isPrivate = visibility == .private
        HStack(spacing: 4) {
            Image(systemName: isPrivate ? "lock.fill" : "globe")
                .font(.system(size: 8, weight: .bold))
            Text(isPrivate ? String(localized: "私密") : String(localized: "公開"))
                .font(Tokens.Fonts.mono(9.5, weight: .bold))
        }
        .foregroundStyle(isPrivate ? palette.orange : palette.ledGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            palette.pillShape.fill(isPrivate ? palette.orangeDim : palette.ledGreen.opacity(0.14))
                .overlay { if palette.isHard { palette.pillShape.stroke(isPrivate ? palette.orange : palette.ledGreen, lineWidth: palette.metrics.border) } }
        )
    }
}

#Preview("P1 首頁") {
    HomeScreen()
        .environment(CompositionRoot())
        .environment(\.palette, .matteBlack)
        .background(Palette.matteBlack.bg)
}
