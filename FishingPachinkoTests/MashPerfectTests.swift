import XCTest
@testable import Dopagaki_Fishing_Collection

final class MashPerfectTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SoundEngine.shared.muted = true
    }

    private func castToMash(result: Rarity) -> GameModel {
        let model = GameModel()
        model.rareLv = 3
        model.reelLv = 0
        model.phase = .idle
        model.pressCast()
        model.releaseCast()
        for _ in 0..<400 where model.phase != .reach { model.tick(0.05) }
        XCTAssertEqual(model.phase, .reach)
        model.result = result
        for _ in 0..<400 where model.phase != .mash { model.tick(0.05) }
        XCTAssertEqual(model.phase, .mash)
        return model
    }

    /// タイムアップ→フッキング(0.55s)→釣果カードまで進める
    private func runOutMash(_ model: GameModel) {
        for _ in 0..<200 where model.phase == .mash { model.tick(0.05) }
        model.tick(0.6)
    }

    private func baseScore(_ caught: Caught) throws -> Int {
        try XCTUnwrap(fishPool[caught.rarity]?.first { $0.name == caught.name }).score
    }

    func testReachingNeedKeepsMashingUntilTimeoutAndCountsDownToPerfect() throws {
        let model = castToMash(result: .ssr)      // need 18, PERFECT 22
        for _ in 0..<18 { model.tapScreen() }
        XCTAssertEqual(model.phase, .mash, "必要数到達で即リゾルブしない")
        XCTAssertEqual(model.mashTapsLeft, 0)
        XCTAssertEqual(model.mashPerfectLeft, 4)
        for _ in 0..<3 { model.tapScreen() }
        XCTAssertEqual(model.mashPerfectLeft, 1)
        model.tapScreen()
        XCTAssertEqual(model.mashPerfectLeft, 0)
        model.tapScreen()
        XCTAssertEqual(model.mashCount, 23)
        XCTAssertEqual(model.phase, .mash)

        runOutMash(model)
        XCTAssertEqual(model.phase, .reveal)
        let caught = try XCTUnwrap(model.reveal)
        XCTAssertTrue(caught.perfect)
        XCTAssertEqual(caught.score, Int(Double(try baseScore(caught)) * 1.5))
    }

    func testMeetingNeedWithoutPerfectIsNormalSuccess() throws {
        let model = castToMash(result: .ssr)
        for _ in 0..<21 { model.tapScreen() }
        XCTAssertEqual(model.mashPerfectLeft, 1)
        runOutMash(model)
        XCTAssertEqual(model.phase, .reveal)
        let caught = try XCTUnwrap(model.reveal)
        XCTAssertFalse(caught.perfect)
        XCTAssertEqual(caught.score, try baseScore(caught))
    }

    func testShortOfNeedStillEscapes() {
        let model = castToMash(result: .ssr)
        for _ in 0..<17 { model.tapScreen() }
        XCTAssertNil(model.mashPerfectLeft)
        XCTAssertEqual(model.mashTapsLeft, 1)
        runOutMash(model)
        XCTAssertEqual(model.phase, .escaping)
        XCTAssertNil(model.reveal)
        XCTAssertEqual(model.escapeReport?.tapsShort, 1)
    }

    func testBluffNeverOffersPerfect() {
        let model = castToMash(result: .ssr)
        model.result = nil
        for _ in 0..<40 { model.tapScreen() }
        XCTAssertNil(model.mashPerfectLeft)
        runOutMash(model)
        XCTAssertEqual(model.phase, .escaping)
    }
}
