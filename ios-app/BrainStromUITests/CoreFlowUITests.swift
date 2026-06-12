import XCTest

// ============================================================
// 前端 E2E（XCUITest，Stub 軌）—— 模擬器內自動點按跑核心流程
// 登入 → 建系統 → 命名解鎖 → 寫內文 → ▦ 結構化(Stub出卡) → 💬 聊天(Stub回覆)
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

    func testCoreFlowLoginCreateEditStructureChat() {
        // 登入
        let login = el("login.apple")
        XCTAssertTrue(login.waitForExistence(timeout: 10), "登入頁未出現")
        login.tap()

        // 建系統
        let create = el("home.create")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "首頁加號未出現")
        create.tap()

        // 命名態：先隨便取 → 解鎖編輯
        let quick = el("note.quickname")
        XCTAssertTrue(quick.waitForExistence(timeout: 10), "命名態快速命名鈕未出現")
        quick.tap()

        // 寫內文
        let cont = el("note.continue")
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "續寫欄未出現（命名未解鎖？）")
        cont.tap()
        cont.typeText("E2E 自動測試內文")

        // 點標題使續寫失焦提交
        let title = el("note.title")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()

        // ▦ 結構化（Stub 回 3 張卡，卡標「核心問題」）
        let structure = el("dock.structure")
        XCTAssertTrue(structure.waitForExistence(timeout: 5), "結構化鍵未出現")
        structure.tap()
        XCTAssertTrue(app.staticTexts["核心問題"].waitForExistence(timeout: 12), "結構化卡片未浮現")

        // 💬 聊天（Stub 串流回覆）
        let chat = el("dock.chat")
        if chat.waitForExistence(timeout: 5) {
            chat.tap()
            let chatInput = app.textViews.firstMatch
            if chatInput.waitForExistence(timeout: 5) {
                chatInput.tap()
                chatInput.typeText("這則在講什麼？")
            }
        }
    }
}
