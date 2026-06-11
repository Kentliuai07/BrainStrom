import Foundation

// ============================================================
// AI 連線設定 —— 來源鏈：Config.xcconfig → Info.plist → 這裡
// 鐵律：token 永不出現在程式碼字面值與 git
// ============================================================

/// AI 後端連線參數。
struct AIConfig: Equatable, Sendable {
    let baseURL: URL
    let authToken: String
    let useStub: Bool

    /// 從 Info.plist 讀取（鍵由 xcconfig 注入）。
    static func fromBundle(_ bundle: Bundle = .main) -> AIConfig? {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "AIBaseURL") as? String,
            let url = URL(string: urlString),
            let token = bundle.object(forInfoDictionaryKey: "AIAuthToken") as? String,
            !token.isEmpty, token != "REPLACE_ME"
        else { return nil }

        let stubFlag = (bundle.object(forInfoDictionaryKey: "AIUseStub") as? String) ?? "YES"
        return AIConfig(baseURL: url, authToken: token, useStub: stubFlag.uppercased() == "YES")
    }
}
