import XCTest
@testable import BrainStrom

// ============================================================
// 系統身份證 · SpecPatch 合併契約測試（階段三 update_spec 通道核心）
// 規則：null/缺鍵=不動；非 null=覆蓋；apis 給了就整陣列替換。
// ============================================================

final class SystemSpecTests: XCTestCase {

    private func patch(_ json: String) -> SpecPatch {
        try! JSONDecoder().decode(SpecPatch.self, from: Data(json.utf8))
    }

    func testPartialMergeKeepsUntouchedFields() {
        let base = SystemSpec(frontend: "SwiftUI", database: "SwiftData")
        let merged = patch(#"{"backend":"Node.js"}"#).merged(into: base)
        XCTAssertEqual(merged.frontend, "SwiftUI")   // 沒給 → 不動
        XCTAssertEqual(merged.database, "SwiftData")  // 沒給 → 不動
        XCTAssertEqual(merged.backend, "Node.js")     // 給了 → 填上
    }

    func testNonNilOverwrites() {
        let base = SystemSpec(frontend: "React")
        let merged = patch(#"{"frontend":"SwiftUI"}"#).merged(into: base)
        XCTAssertEqual(merged.frontend, "SwiftUI")
    }

    func testApisReplacedWholesale() {
        let base = SystemSpec(apis: ["Stripe"])
        let merged = patch(#"{"apis":["Stripe","Twilio"]}"#).merged(into: base)
        XCTAssertEqual(merged.apis, ["Stripe", "Twilio"])   // 整陣列替換
    }

    func testMissingApisKeepsOld() {
        let base = SystemSpec(apis: ["Stripe"])
        let merged = patch(#"{"database":"PostgreSQL"}"#).merged(into: base)
        XCTAssertEqual(merged.apis, ["Stripe"])   // 缺鍵 → 不動
    }

    func testBackendRealShapeDecodesAndMerges() {
        // 後端實測回傳的形狀
        let merged = patch(#"{"frontend":"React","backend":"Node.js","database":"PostgreSQL","deployMethod":"Fly.io"}"#)
            .merged(into: SystemSpec())
        XCTAssertEqual(merged.frontend, "React")
        XCTAssertEqual(merged.backend, "Node.js")
        XCTAssertEqual(merged.database, "PostgreSQL")
        XCTAssertEqual(merged.deployMethod, "Fly.io")
        XCTAssertFalse(merged.isEmpty)
    }

    func testEmptySpecIsEmpty() {
        XCTAssertTrue(SystemSpec().isEmpty)
        XCTAssertFalse(SystemSpec(name: "X").isEmpty)
        XCTAssertFalse(SystemSpec(apis: ["A"]).isEmpty)
    }

    func testRoundTripCodable() throws {
        let spec = SystemSpec(name: "BrainStrom", frontend: "SwiftUI", apis: ["Anthropic"], server: "Fly.io")
        let data = try JSONEncoder().encode(spec)
        let back = try JSONDecoder().decode(SystemSpec.self, from: data)
        XCTAssertEqual(spec, back)
    }
}
