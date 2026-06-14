import SwiftUI
import Network

// ============================================================
// 根視圖 —— 解析機殼色票、注入環境、會話路由
// 對齊 web frame()：離線橫條（頂）＋ Toast 膠囊（底）掛在全 App 最上層
// ============================================================

struct RootView: View {

    @Environment(CompositionRoot.self) private var root
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var online = true

    var body: some View {
        let palette = root.theme.palette(for: colorScheme)

        Group {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("note") || args.contains("settings") || args.contains("login")
                || args.contains("coach") || args.contains("structure") || args.contains("persona") {
                previewScreen
            } else {
                routedContent
            }
            #else
            routedContent
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            OfflineBar(online: online)
                .animation(Motion.layer, value: online)
        }
        .overlay(alignment: .bottom) {
            if let message = root.toast.message {
                ToastBanner(text: message)
                    .padding(.bottom, 40)
            }
        }
        .environment(\.palette, palette)
        .preferredColorScheme(root.theme.preferredColorScheme())
        .task {
            root.attachRepository(context: modelContext)
            await root.restoreSession()
        }
        .task { await monitorConnectivity() }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch root.session {
        case .checking:
            BootCheckView()
        case .signedOut:
            LoginScreen()
        case .signedIn:
            HomeScreen()
        }
    }

    #if DEBUG
    /// DEBUG 啟動參數路由：-previewScreen note|settings|login（僅供視覺驗收，Release 不編入）。
    @ViewBuilder
    private var previewScreen: some View {
        let arg = ProcessInfo.processInfo.arguments
        if arg.contains("note"), let repo = root.repository,
           let sys = (try? repo.systems())?.first ?? (try? repo.createSystem(name: "")),
           let note = try? repo.documentNote(for: sys.id) {
            NavigationStack { NoteDetailScreen(noteID: note.id) }
        } else if arg.contains("settings") {
            NavigationStack { SettingsScreen() }
        } else if arg.contains("login") {
            LoginScreen()
        } else if arg.contains("coach") {
            DebugPreviewHost(arg: "coach")
        } else if arg.contains("structure") {
            DebugPreviewHost(arg: "structure")
        } else if arg.contains("persona") {
            DebugPreviewHost(arg: "persona")
        }
    }
    #endif

    /// 網路狀態監聽（離線橫條的資料來源）。
    private func monitorConnectivity() async {
        let monitor = NWPathMonitor()
        let stream = AsyncStream<Bool> { continuation in
            monitor.pathUpdateHandler = { continuation.yield($0.status == .satisfied) }
            monitor.start(queue: DispatchQueue(label: "net.monitor"))
            continuation.onTermination = { _ in monitor.cancel() }
        }
        for await isOnline in stream {
            await MainActor.run { online = isOnline }
        }
    }
}

/// 啟動自檢（P0 設計稿的「通電儀式」；逐畫面實作階段補完整動效）。
struct BootCheckView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s6) {
            HStack(spacing: 5) {
                Text(verbatim: "BrainStrom")
                    .font(Tokens.Fonts.display(30))
                    .foregroundStyle(palette.print)
                NotchedRectangle(notch: 3, corner: .topTrailing, cornerRadius: 0)
                    .fill(palette.orange)
                    .frame(width: 9, height: 9)
                    .offset(y: -8)
            }
            VStack(alignment: .leading, spacing: 8) {
                bootLine(status: "OK", text: String(localized: "本機資料庫"))
                bootLine(status: "..", text: String(localized: "載入你的系統"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 34)
        .background(palette.bg)
    }

    private func bootLine(status: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: "[ \(status) ]")
                .foregroundStyle(status == "OK" ? palette.ledGreen : palette.ledAmber)
            Text(text)
                .foregroundStyle(palette.print2)
        }
        .font(Tokens.Fonts.mono(10.5))
        .kerning(0.6)
    }
}

#Preview("啟動自檢") {
    BootCheckView()
        .environment(\.palette, .matteBlack)
        .background(Palette.matteBlack.bg)
}

#if DEBUG
/// DEBUG 視覺驗收宿主：為 coach/structure/persona 三屏建系統＋灌範例 spec 後直接呈現。
private struct DebugPreviewHost: View {
    let arg: String
    @Environment(CompositionRoot.self) private var root
    @Environment(\.palette) private var palette
    @State private var systemID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if arg == "persona" {
                    PersonaBatchView(appName: String(localized: "記帳 App"),
                                     oneLiner: String(localized: "幫人記錄日常開銷"),
                                     country: "TW", onSelect: { _ in }, onCancel: {})
                } else if let id = systemID {
                    if arg == "structure" {
                        ScrollView { SystemStructureView(systemID: id, active: true).padding(16) }
                            .background(palette.bg)
                    } else {
                        AICoachView(systemID: id, autoKickoff: false, active: true)
                    }
                } else {
                    palette.bg.ignoresSafeArea()
                }
            }
        }
        .task { seed() }
    }

    private func seed() {
        guard arg == "structure" || arg == "coach", systemID == nil,
              let repo = root.repository,
              let result = try? repo.createSystemWithPrimaryNote(name: String(localized: "記帳 App"),
                                                                 initialContent: String(localized: "幫人記錄日常開銷")) else { return }
        if arg == "structure" {
            var spec = SystemSpec()
            spec.oneLiner = "幫上班族 30 秒記一筆帳"
            spec.targetUser = "想存錢但懶得記帳的上班族"
            spec.painPoint = "現有 App 記一筆要點太多次"
            spec.coreValue = "用一句話自然語言記帳"
            spec.coreFeatures = "語音記帳、自動分類、月報表"
            spec.frontend = "SwiftUI"
            spec.backend = "Node.js"
            try? repo.updateSystemSpec(systemID: result.system.id, spec: spec)
        }
        systemID = result.system.id
    }
}
#endif
