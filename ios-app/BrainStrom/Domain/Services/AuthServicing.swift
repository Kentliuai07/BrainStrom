import Foundation

// ============================================================
// 帳號服務抽象（Sign in with Apple）
// ============================================================

/// 已登入帳號。
struct UserAccount: Equatable, Codable, Sendable {
    let userID: String
    let email: String?
}

/// 帳號服務協議。
protocol AuthServicing: Sendable {
    /// 冷啟動憑證檢查（啟動自檢的一行）。
    func restoreSession() async -> UserAccount?

    /// Sign in with Apple。
    func signInWithApple() async throws -> UserAccount

    /// 登出（本機資料保留）。
    func signOut() async

    /// 刪除帳號（危險區第三道閘：需 Apple 重新驗證後呼叫）。
    func deleteAccount() async throws
}
