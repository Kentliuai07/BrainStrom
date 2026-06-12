import XCTest

// ============================================================
// 前端 E2E（XCUITest，Stub 軌）—— 階段三 v3 新流程
// 登入 → ＋建專案(彈窗輸入名稱) → 預設教練分頁自動開場 → 📝加入筆記
// → 系統結構 ▦結構化(Stub出卡) → 返回我的系統列表
// ============================================================

@MainActor
final class CoreFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestStub", "-uiTestReset"]
        app.launch()
    }

    /// 依 identifier 取元素（SwiftUI 元素型別不定，用 any 後代查詢最穩）。
    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testCoreFlowCreateProjectCoachAddNoteStructure() {
        // 登入
        let login = el("login.apple")
        XCTAssertTrue(login.waitForExistence(timeout: 10), "登入頁未出現")
        login.tap()

        // ＋ 建專案 → 弹窗①输入名稱/靈感
        let create = el("home.create")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "首頁加號未出現")
        create.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8), "建專案彈窗①未出現")
        let nameField = alert.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "名稱輸入框未出現")
        nameField.tap()
        nameField.typeText("健身 App")
        alert.buttons["下一步"].tap()

        // 弹窗②：选「进 AI 引导」
        let guidedBtn = app.buttons["🤖 進 AI 引導（建議）"]
        XCTAssertTrue(guidedBtn.waitForExistence(timeout: 8), "建專案彈窗②（選模式）未出現")
        guidedBtn.tap()

        // 預設停在 AI 教練分頁並自動引導開場（Stub kickoff 回「## 教練開場」）
        XCTAssertTrue(app.staticTexts["教練開場"].waitForExistence(timeout: 15), "AI 教練未自動引導開場")

        // 📝 加入筆記：把教練回覆加進主筆記
        let addNote = el("coach.addnote")
        XCTAssertTrue(addNote.waitForExistence(timeout: 5), "加入筆記鈕未出現")
        addNote.tap()

        // 系統結構分頁 → ▦ 結構化（操作主筆記，Stub 回 3 張卡，卡標「核心問題」）
        let structureTab = el("systemDetail.tab.structure")
        XCTAssertTrue(structureTab.waitForExistence(timeout: 8), "系統結構分頁未出現")
        structureTab.tap()
        let runStructure = el("structure.run")
        XCTAssertTrue(runStructure.waitForExistence(timeout: 8), "結構化按鈕未出現")
        runStructure.tap()
        XCTAssertTrue(app.staticTexts["核心問題"].waitForExistence(timeout: 12), "結構化卡片未浮現")

        // 返回「我的系統」列表（專案首頁返回鍵）
        let sysBack = el("systemDetail.back")
        XCTAssertTrue(sysBack.waitForExistence(timeout: 5), "專案首頁返回鍵未出現")
        sysBack.tap()
        XCTAssertTrue(el("home.create").waitForExistence(timeout: 8), "未能返回我的系統列表")
    }
}
