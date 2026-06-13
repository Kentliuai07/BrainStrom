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

    // ===== build7：5 区扩充 =====

    func testNewIdeaFieldsMerge() {
        let merged = patch(#"{"oneLiner":"给健身新手的AI排课","painPoint":"不会排课","coreFeatures":"排课/纠错/营养"}"#)
            .merged(into: SystemSpec())
        XCTAssertEqual(merged.oneLiner, "给健身新手的AI排课")
        XCTAssertEqual(merged.painPoint, "不会排课")
        XCTAssertEqual(merged.coreFeatures, "排课/纠错/营养")
    }

    func testCoreFilledCountAndComplete() {
        var s = SystemSpec()
        XCTAssertEqual(s.coreFilledCount, 0); XCTAssertFalse(s.coreComplete)
        s.oneLiner = "x"; s.targetUser = "y"; s.painPoint = "z"
        XCTAssertEqual(s.coreFilledCount, 3)
        XCTAssertTrue(s.infoEnoughForCompetitors)   // 一句话+痛点+目标用户齐 → 可找竞品
        XCTAssertFalse(s.coreComplete)
        s.coreFeatures = "f"
        XCTAssertEqual(s.coreFilledCount, 4); XCTAssertTrue(s.coreComplete)
    }

    func testMergeMarksConfirmed() {
        let merged = patch(#"{"oneLiner":"a","frontend":"SwiftUI"}"#).merged(into: SystemSpec())
        XCTAssertTrue(merged.confirmedFields.contains("oneLiner"))
        XCTAssertTrue(merged.confirmedFields.contains("frontend"))
        XCTAssertFalse(merged.confirmedFields.contains("painPoint"))
    }

    func testBackwardCompatDecodeOld7FieldJSON() throws {
        // 旧资料(build6 之前)只有 7 技术字段 → 新字段应安全默认 nil/[]
        let oldJSON = #"{"name":"旧专案","frontend":"React","apis":["Stripe"]}"#
        let s = try JSONDecoder().decode(SystemSpec.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(s.name, "旧专案")
        XCTAssertEqual(s.frontend, "React")
        XCTAssertEqual(s.apis, ["Stripe"])
        XCTAssertNil(s.oneLiner); XCTAssertNil(s.painPoint)
        XCTAssertTrue(s.competitors.isEmpty); XCTAssertTrue(s.confirmedFields.isEmpty)
    }

    func testCompetitorItemRoundTrip() throws {
        let c = CompetitorItem(source: "app_store", title: "Fitbod", url: "https://x", subtitle: "Fitbod Inc.")
        let back = try JSONDecoder().decode(CompetitorItem.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(c, back)
    }

    func testIsEmptyConsidersNewFields() {
        XCTAssertTrue(SystemSpec().isEmpty)
        XCTAssertFalse(SystemSpec(oneLiner: "x").isEmpty)
        XCTAssertFalse(SystemSpec(competitors: [CompetitorItem(source: "github", title: "r", url: "u")]).isEmpty)
    }

    // build12：新增 source "article"（相关文章）——坐实新值编解码与旧解码相容。
    func testArticleSourceRoundTrip() throws {
        let c = CompetitorItem(source: "article", title: "t", url: "https://x", subtitle: "example.com", summary: "繁中一句")
        let back = try JSONDecoder().decode(CompetitorItem.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(c, back)
        XCTAssertEqual(back.source, "article")
        XCTAssertEqual(back.summary, "繁中一句")
    }

    func testArticleSourceDecodesFromRawJSON() throws {
        let raw = Data(#"{"source":"article","title":"t","url":"u","summary":"s"}"#.utf8)
        let a = try JSONDecoder().decode(CompetitorItem.self, from: raw)
        XCTAssertEqual(a.source, "article")
        XCTAssertEqual(a.summary, "s")
        XCTAssertNil(a.subtitle)
        // 旧持久化竞品（无 summary）仍正确解出 summary == nil
        let old = Data(#"{"source":"web","title":"t","url":"u"}"#.utf8)
        let w = try JSONDecoder().decode(CompetitorItem.self, from: old)
        XCTAssertEqual(w.source, "web")
        XCTAssertNil(w.summary)
    }
}
