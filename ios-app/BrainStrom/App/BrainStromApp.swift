import SwiftUI
import SwiftData

// ============================================================
// App 入口
// ============================================================

@main
struct BrainStromApp: App {

    @State private var root = CompositionRoot()
    private let container: ModelContainer

    init() {
        // UI 測試：-uiTestReset → 記憶體容器（每次乾淨起跑、與本機資料隔離）
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTestReset")
        do {
            container = try ModelContainer(
                for: SystemEntity.self, NoteEntity.self, CardEntity.self, RevisionEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("ModelContainer 初始化失敗：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(root)
        }
        .modelContainer(container)
    }
}
