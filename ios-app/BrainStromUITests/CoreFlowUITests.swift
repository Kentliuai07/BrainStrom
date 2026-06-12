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

        // 建系統 → 進專案首頁（三分頁，預設「開發筆記」清單）
        let create = el("home.create")
        XCTAssertTrue(create.waitForExistence(timeout: 10), "首頁加號未出現")
        create.tap()

        // 階段三：開發筆記清單 → 新增第一篇筆記 → 進單篇編輯頁
        let newNote = el("noteslist.create")
        XCTAssertTrue(newNote.waitForExistence(timeout: 10), "筆記清單新增鍵未出現")
        newNote.tap()

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

        // 💬 聊天（Stub 串流回覆，含 markdown）
        let chat = el("dock.chat")
        XCTAssertTrue(chat.waitForExistence(timeout: 5), "聊天鍵未出現")
        chat.tap()
        let chatInput = el("chat.input")
        XCTAssertTrue(chatInput.waitForExistence(timeout: 5), "聊天輸入框未出現")
        chatInput.tap()
        chatInput.typeText("這則在講什麼？")
        el("chat.send").tap()
        // markdown 渲染驗證：Stub 回的「## 觀測建議」標題應被解析渲染成可見文字
        XCTAssertTrue(app.staticTexts["觀測建議"].waitForExistence(timeout: 10), "AI markdown 標題未渲染")

        // 階段三：結構卡片移到「系統結構」分頁。返回專案首頁 → 系統結構 → ▦ 結構化
        let back = el("note.back")
        XCTAssertTrue(back.waitForExistence(timeout: 5), "筆記返回鍵未出現")
        back.tap()
        let structureTab = el("systemDetail.tab.structure")
        XCTAssertTrue(structureTab.waitForExistence(timeout: 8), "系統結構分頁未出現")
        structureTab.tap()
        let runStructure = el("structure.run")
        XCTAssertTrue(runStructure.waitForExistence(timeout: 8), "結構化按鈕未出現")
        runStructure.tap()
        // Stub 回 3 張卡，卡標「核心問題」
        XCTAssertTrue(app.staticTexts["核心問題"].waitForExistence(timeout: 12), "結構化卡片未浮現")

        // 返回專案首頁仍可回到「我的系統」列表（修復：專案首頁有返回鍵）
        let sysBack = el("systemDetail.back")
        XCTAssertTrue(sysBack.waitForExistence(timeout: 5), "專案首頁返回鍵未出現")
        sysBack.tap()
        XCTAssertTrue(el("home.create").waitForExistence(timeout: 8), "未能返回我的系統列表")
    }
}
