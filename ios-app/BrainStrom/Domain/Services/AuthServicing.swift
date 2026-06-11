import Foundation

// ============================================================
// 帳號服務抽象（Sign in with Apple）
// ============================================================

/// 使用者偏好（《整合契約 §4》：updatePrefs 是 merge 不是替換）。
struct UserPrefs: Equatable, Codable, Sendable {
    var ideaNudge: Bool = true
}

/// 已登入帳號。
struct UserAccount: Equatable, Codable, Sendable {
    let userID: String
    let email: String?
    var prefs: UserPrefs

    init(userID: String, email: String?, prefs: UserPrefs = UserPrefs()) {
        self.userID = userID
        self.email = email
        self.prefs = prefs
    }

    // 向後相容：舊憑證 blob 沒有 prefs 鍵時給預設。
    enum CodingKeys: String, CodingKey { case userID, email, prefs }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(String.self, forKey: .userID)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        prefs = try c.decodeIfPresent(UserPrefs.self, forKey: .prefs) ?? UserPrefs()
    }
}

/// 帳號服務協議。
protocol AuthServicing: Sendable {
    /// 冷啟動憑證檢查（啟動自檢的一行）。
    func restoreSession() async -> UserAccount?

    /// Sign in with Apple。
    func signInWithApple() async throws -> UserAccount

    /// 登出（本機資料保留）。
    func signOut() async

    /// 偏好合併更新（《契約 §5》auth.updatePrefs 觸點）。
    func updatePrefs(_ prefs: UserPrefs) async -> UserAccount?

    /// 刪除帳號（危險區第三道閘：需 Apple 重新驗證後呼叫）。
    func deleteAccount() async throws
}
