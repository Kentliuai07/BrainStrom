import Foundation
import SwiftData

// ============================================================
// 組合根 —— 全 App 唯一的依賴拼裝點
// UI 只認識協議；Stub/Live 在這裡一處切換（AI_USE_STUB）
// ============================================================

/// 登入會話狀態。
enum SessionState: Equatable {
    case checking                // 啟動自檢中
    case signedOut
    case signedIn(UserAccount)
}

@MainActor
@Observable
final class CompositionRoot {

    // —— 服務（抽象）——
    let ai: any AIServicing
    let auth: any AuthServicing
    let theme = ThemeStore()
    let toast = ToastModel()
    private(set) var repository: (any NotesRepositoring)?

    // —— 會話 ——
    private(set) var session: SessionState = .checking

    init() {
        // UI 測試：-uiTestStub → 強制罐頭 AI（確定性、不打網路）
        let forceStub = ProcessInfo.processInfo.arguments.contains("-uiTestStub")
        let config = AIConfig.fromBundle()
        if let config, !config.useStub, !forceStub {
            self.ai = AIServiceLive(config: config)
        } else {
            self.ai = AIServiceStub()
        }
        self.auth = AuthServiceStub()  // 真 Sign in with Apple 於 P0 實作時替換
    }

    /// RootView 出現時掛上 SwiftData context。
    func attachRepository(context: ModelContext) {
        guard repository == nil else { return }
        repository = NotesRepository(context: context)
    }

    /// 冷啟動憑證檢查（P0 自檢層）。
    func restoreSession() async {
        // UI 測試重置：清會話、從登入頁起跑（確定性）
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            await auth.signOut()
            session = .signedOut
            return
        }
        let account = await auth.restoreSession()
        session = account.map(SessionState.signedIn) ?? .signedOut
    }

    func signIn() async {
        do {
            let account = try await auth.signInWithApple()
            Haptics.success()
            session = .signedIn(account)
        } catch {
            Haptics.error()
            session = .signedOut
        }
    }

    func signOut() async {
        await auth.signOut()
        session = .signedOut
    }

    /// 刪除帳號（危險區）：刪帳→登出→回登入頁。
    func deleteAccount() async {
        try? await auth.deleteAccount()
        await auth.signOut()
        session = .signedOut
    }

    /// 更新偏好（點子助攻總開關），同步回 session。
    func updatePrefs(ideaNudge: Bool) async {
        if let updated = await auth.updatePrefs(UserPrefs(ideaNudge: ideaNudge)) {
            session = .signedIn(updated)
        }
    }

    /// 目前點子助攻偏好。
    var ideaNudgeEnabled: Bool {
        if case let .signedIn(account) = session { return account.prefs.ideaNudge }
        return true
    }
}
