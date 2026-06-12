import XCTest
@testable import BrainStrom

// ============================================================
// SSE 解析器測試 —— 涵蓋 9 種事件 + 斷行/flush/容錯
// ============================================================

final class SSEParserTests: XCTestCase {

    // MARK: - 9 種事件逐一

    func testDelta() {
        XCTAssertEqual(SSEEventMapper.map(jsonString: #"{"type":"delta","text":"嗨"}"#), .delta("嗨"))
    }

    func testDeltaEmptyIgnored() {
        XCTAssertNil(SSEEventMapper.map(jsonString: #"{"type":"delta","text":""}"#))
    }

    func testUsage() {
        let e = SSEEventMapper.map(jsonString:
            #"{"type":"usage","input_tokens":10,"output_tokens":5,"cache_read_input_tokens":2,"model":"claude"}"#)
        XCTAssertEqual(e, .usage(AIUsage(inputTokens: 10, outputTokens: 5, cacheReadInputTokens: 2, model: "claude")))
    }

    func testProgress() {
        let e = SSEEventMapper.map(jsonString: #"{"type":"progress","current":2,"total":3,"message":"整理中"}"#)
        XCTAssertEqual(e, .progress(current: 2, total: 3, message: "整理中"))
    }

    func testCardStart() {
        let e = SSEEventMapper.map(jsonString: #"{"type":"card_start","index":0,"cardType":"text","title":"核心問題"}"#)
        XCTAssertEqual(e, .cardStart(index: 0, title: "核心問題", type: "text"))
    }

    func testCardStartDualTrackTypeName() {
        // 真後端目前：開始事件 type=卡片型別名（非 card_start），有 index+title → 當 card_start
        let e = SSEEventMapper.map(jsonString: #"{"type":"systemName","index":2,"title":"命名建議"}"#)
        XCTAssertEqual(e, .cardStart(index: 2, title: "命名建議", type: "systemName"))
    }

    func testCardDoneOptimizeAdd() {
        let e = SSEEventMapper.map(jsonString:
            #"{"type":"card_done","index":1,"card":{"action":"add","type":"text","content":"內容","position":1}}"#)
        guard case let .cardDone(index, card) = e else { return XCTFail("非 cardDone") }
        XCTAssertEqual(index, 1)
        XCTAssertEqual(card.action, "add")
        XCTAssertEqual(card.content, "內容")
        XCTAssertEqual(card.position, 1)
    }

    func testCardDoneStructure() {
        let e = SSEEventMapper.map(jsonString:
            #"{"type":"card_done","index":0,"card":{"type":"text","title":"方法","content":"步驟","absorbed":["b1","b2"]}}"#)
        guard case let .cardDone(_, card) = e else { return XCTFail("非 cardDone") }
        XCTAssertEqual(card.title, "方法")
        XCTAssertEqual(card.absorbed, ["b1", "b2"])
        XCTAssertNil(card.action)
    }

    func testCardRemoved() {
        XCTAssertEqual(SSEEventMapper.map(jsonString: #"{"type":"card_removed","cardId":"c9"}"#), .cardRemoved(cardId: "c9"))
    }

    func testProposal() {
        let e = SSEEventMapper.map(jsonString:
            #"{"type":"proposal","items":[{"action":"edit_text","label":"幫我補","args":{"instruction":"補一段"}},{"action":"structure","label":"分卡片"}]}"#)
        guard case let .proposal(items) = e else { return XCTFail("非 proposal") }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].action, "edit_text")
        XCTAssertEqual(items[0].instruction, "補一段")
        XCTAssertEqual(items[1].action, "structure")
        XCTAssertNil(items[1].instruction)
    }

    func testDone() {
        XCTAssertEqual(SSEEventMapper.map(jsonString: #"{"type":"done"}"#), .done)
    }

    func testError() {
        XCTAssertEqual(SSEEventMapper.map(jsonString: #"{"type":"error","code":"rate_limited","error":"忙線"}"#),
                       .error(code: "rate_limited", message: "忙線"))
    }

    // MARK: - 容錯

    func testUnknownTypeTolerated() {
        XCTAssertNil(SSEEventMapper.map(jsonString: #"{"type":"future_event","x":1}"#))
    }

    func testMissingTypeReturnsNil() {
        XCTAssertNil(SSEEventMapper.map(jsonString: #"{"text":"沒有 type"}"#))
    }

    func testGarbageJSONReturnsNil() {
        XCTAssertNil(SSEEventMapper.map(jsonString: "not json at all"))
    }

    // MARK: - 累積器：斷行 / 空行觸發 / flush

    func testAccumulatorEmitsOnBlankLine() {
        var acc = SSEAccumulator()
        XCTAssertNil(acc.feed(line: #"data: {"type":"delta","text":"a"}"#))
        let out = acc.feed(line: "")  // 空行 → 吐出
        XCTAssertEqual(out, #"{"type":"delta","text":"a"}"#)
    }

    func testAccumulatorFlushWithoutTrailingBlank() {
        var acc = SSEAccumulator()
        XCTAssertNil(acc.feed(line: #"data: {"type":"done"}"#))
        XCTAssertEqual(acc.flush(), #"{"type":"done"}"#)  // 沒有結尾空行也補吐
    }

    func testAccumulatorIgnoresCommentLine() {
        var acc = SSEAccumulator()
        XCTAssertNil(acc.feed(line: ": heartbeat"))
        XCTAssertNil(acc.flush())
    }

    func testEndToEndLineStream() {
        // 模擬整段串流逐行進來：delta → usage → done
        var acc = SSEAccumulator()
        var events: [AIEvent] = []
        let lines = [
            #"data: {"type":"delta","text":"hi"}"#, "",
            #"data: {"type":"usage","input_tokens":1,"output_tokens":2,"cache_read_input_tokens":0,"model":"m"}"#, "",
            #"data: {"type":"done"}"#, "",
        ]
        for line in lines {
            if let json = acc.feed(line: line), let e = SSEEventMapper.map(jsonString: json) {
                events.append(e)
            }
        }
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.first, .delta("hi"))
        XCTAssertEqual(events.last, .done)
    }
}
