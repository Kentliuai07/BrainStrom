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
}

struct HomeScreen: View {

    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette

    @State private var path = NavigationPath()
    @State private var systems: [NoteSystem] = []
    @State private var loaded = false
    @State private var loadFailed = false
    @State private var showCreateDialog = false
    @State private var showModeDialog = false
    @State private var newProjectName = ""

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
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: path) { _, new in
            if new.isEmpty { reload() }  // 從筆記/設定返回 → 刷新清單
        }
        // 弹窗①：输入名称/灵感
        .alert(String(localized: "新增專案"), isPresented: $showCreateDialog) {
            TextField(String(localized: "系統名稱，或一個靈感…"), text: $newProjectName)
                .accessibilityIdentifier("home.projectNameInput")
            Button(String(localized: "下一步")) {
                // 接力弹窗②（稍延一拍让弹窗①先收）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showModeDialog = true }
            }
            Button(String(localized: "取消"), role: .cancel) { newProjectName = "" }
        } message: {
            Text(String(localized: "先給專案取個名字或丟一個靈感。"))
        }
        // 弹窗②：选「进 AI 引导」或「之后慢慢填」
        .confirmationDialog(String(localized: "要怎麼開始？"), isPresented: $showModeDialog, titleVisibility: .visible) {
            Button(String(localized: "🤖 進 AI 引導（建議）")) { createProject(mode: .kickoff) }
            Button(String(localized: "📝 之後慢慢填，自己寫")) { createProject(mode: .notes) }
            Button(String(localized: "取消"), role: .cancel) { newProjectName = "" }
        } message: {
            Text(String(localized: "進引導：AI 一題一題帶你把專案想清楚。慢慢填：先自由寫，AI 在旁邊偵測幫你記。"))
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
                newProjectName = ""; showCreateDialog = true
            }
            .accessibilityIdentifier("home.create")
        }
        .padding(.bottom, Tokens.Spacing.s4)
    }

    /// 圓形圖標鈕（web .iconbtn / .iconbtn.accent）。
    private func circleIcon(system: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(accent ? palette.orange : palette.print2)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(palette.panel)
                        .overlay(Circle().strokeBorder(
                            accent ? palette.orange.opacity(0.5) : palette.line, lineWidth: 1))
                )
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
            RoundedRectangle(cornerRadius: Tokens.Radius.input)
                .fill(palette.orangeDim)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.input)
                    .strokeBorder(palette.orange.opacity(0.26), lineWidth: 1))
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
                NotchedRectangle()
                    .strokeBorder(palette.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            Button {
                Haptics.press()
                newProjectName = ""; showCreateDialog = true
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

    /// build7：弹窗②选模式后 → 原子建系統+主筆記 → 進專案首頁（kickoff→教練自动开场；notes→开发笔记）。
    private func createProject(mode: CreationMode) {
        guard let repository = root.repository else { return }
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        newProjectName = ""
        let title = name.isEmpty ? String(localized: "未命名專案") : name
        guard let result = try? repository.createSystemWithPrimaryNote(name: title) else { return }
        path.append(HomeRoute.systemDetail(id: result.system.id, mode: mode))
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
                            .background(Capsule().strokeBorder(palette.line, lineWidth: 1))
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
            Capsule().fill(isPrivate ? palette.orangeDim : palette.ledGreen.opacity(0.14))
        )
    }
}

#Preview("P1 首頁") {
    HomeScreen()
        .environment(CompositionRoot())
        .environment(\.palette, .matteBlack)
        .background(Palette.matteBlack.bg)
}
