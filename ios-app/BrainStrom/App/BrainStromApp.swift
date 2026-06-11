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
        do {
            container = try ModelContainer(
                for: SystemEntity.self, NoteEntity.self, CardEntity.self, RevisionEntity.self
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
