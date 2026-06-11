import Foundation

// ============================================================
// 帳號服務 · 開發替身 —— Sign in with Apple 真實作於畫面階段接上
// ============================================================

struct AuthServiceStub: AuthServicing {

    private static let storageKey = "stub.account"

    func restoreSession() async -> UserAccount? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(UserAccount.self, from: data)
    }

    func signInWithApple() async throws -> UserAccount {
        try await Task.sleep(for: .milliseconds(600))
        let account = UserAccount(userID: "stub-user", email: "kentliuai08@gmail.com")
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        return account
    }

    func signOut() async {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    func deleteAccount() async throws {
        try await Task.sleep(for: .milliseconds(600))
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}
