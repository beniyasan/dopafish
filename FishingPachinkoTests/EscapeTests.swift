import XCTest
@testable import Dopagaki_Fishing_Collection

final class EscapeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SoundEngine.shared.muted = true
    }

    private func freshModel() -> GameModel {
        let model = GameModel()
        model.rareLv = 3
        model.reelLv = 0
        model.phase = .idle
        return model
    }

    private func startRush(spins: Int) -> GameModel {
        let model = freshModel()
        model.phase = .reveal
        model.reveal = Caught(name: "テスト魚", imageName: "FishMadai", rarity: .ur, cm: 50, score: 100,
                              medals: 8, perfect: false, isRecord: false, rushGain: spins, isSmall: false)
        model.dismissReveal()
        model.tick(2.21)
        XCTAssertEqual(model.phase, .idle)
        return model
    }

    /// 実際の魚（result）を固定してから連打フェーズまで進める
    private func castToMash(_ model: GameModel, result: Rarity) {
        model.pressCast()
        model.releaseCast()
        for _ in 0..<400 where model.phase != .reach { model.tick(0.05) }
        XCTAssertEqual(model.phase, .reach)
        model.result = result
        for _ in 0..<400 where model.phase != .mash { model.tick(0.05) }
        XCTAssertEqual(model.phase, .mash)
    }

    private func runOutMash(_ model: GameModel) {
        for _ in 0..<200 where model.phase == .mash { model.tick(0.05) }
        XCTAssertEqual(model.phase, .escaping)
    }

    private func dexTotal() -> Int {
        DexStore.shared.records.values.reduce(0) { $0 + $1[0] }
    }

    func testLineBreakShowsActualRarityAndShortfallWithoutRewards() throws {
        let model = freshModel()
        castToMash(model, result: .ssr)
        XCTAssertEqual(model.mashTapsLeft, 18)
        for _ in 0..<13 { model.tapScreen() }
        XCTAssertEqual(model.mashTapsLeft, 5)
        for _ in 0..<2 { model.tapScreen() }
        XCTAssertEqual(model.mashTapsLeft, 3)
        let score = model.score
        let medals = model.medals
        let dex = dexTotal()
        runOutMash(model)

        let report = try XCTUnwrap(model.escapeReport)
        guard case .lineBreak(let rarity, let name, _, let cm, _) = report.kind else {
            return XCTFail("expected line break")
        }
        XCTAssertEqual(rarity, .ssr)
        let spec = try XCTUnwrap(fishPool[.ssr]?.first { $0.name == name })
        XCTAssertTrue(spec.cm.contains(cm))
        XCTAssertEqual(report.tapsShort, 3)
        XCTAssertEqual(report.progress, 15.0 / 18.0, accuracy: 0.001)
        XCTAssertTrue(report.isNearMiss)
        XCTAssertEqual(report.headline, "あと3回だった!!")
        XCTAssertNil(model.mashTapsLeft)
        XCTAssertNil(model.reveal)
        XCTAssertEqual(model.score, score)
        XCTAssertEqual(model.medals, medals)
        XCTAssertEqual(model.combo, 0)
        XCTAssertEqual(dexTotal(), dex)
    }

    func testBluffShowsNoFishDetails() throws {
        let model = freshModel()
        castToMash(model, result: .sr)
        model.result = nil
        for _ in 0..<5 { model.tapScreen() }
        runOutMash(model)
        let report = try XCTUnwrap(model.escapeReport)
        XCTAssertEqual(report.kind, .bluff)
        XCTAssertEqual(report.tapsShort, 0)
        XCTAssertFalse(report.isNearMiss)
        XCTAssertFalse(report.isBigFish)
        XCTAssertEqual(report.displayName, "？？？")
        XCTAssertEqual(report.headline, "影だけだった…")
    }

    func testMashTapsAfterEscapeDoNotSkipCardImmediately() {
        let model = freshModel()
        castToMash(model, result: .sr)
        runOutMash(model)
        model.tapScreen()
        model.dismissEscape()
        XCTAssertEqual(model.phase, .escaping)
        XCTAssertNotNil(model.escapeReport)
        model.tick(EscapeReport.skipLockDuration + 0.01)
        model.tapScreen()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.escapeReport)
        model.tapScreen()
        model.tick(EscapeReport.displayDuration)
        XCTAssertEqual(model.phase, .idle)
    }

    func testCardTimesOutAndAutoCastsOnceAfterward() {
        let model = freshModel()
        castToMash(model, result: .sr)
        model.autoCast = true
        runOutMash(model)
        model.tick(EscapeReport.displayDuration - 0.05)
        XCTAssertEqual(model.phase, .escaping)
        model.tick(0.1)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.escapeReport)
        model.tick(1.01)
        XCTAssertEqual(model.phase, .flying)
    }

    func testRushLastCastEscapeShowsCardBeforeFinish() {
        let model = startRush(spins: 1)
        castToMash(model, result: .ssr)
        XCTAssertEqual(model.rushLeft, 0)
        runOutMash(model)
        XCTAssertNotNil(model.escapeReport)
        XCTAssertTrue(model.rushActive)
        XCTAssertNil(model.rushSummary)
        model.tick(EscapeReport.displayDuration + 0.01)
        XCTAssertEqual(model.phase, .rushEnding)
        XCTAssertNil(model.escapeReport)
        XCTAssertEqual(model.rushSummary?.casts, 1)
        XCTAssertEqual(model.rushLeft, 0)
    }

    func testReportTextAndUndiscoveredNameHiding() {
        let unknown = EscapeReport(kind: .lineBreak(rarity: .ur, fishName: "黄金龍魚", imageName: "FishGoldenDragonfish",
                                                    cm: 400, discovered: false), mashCount: 10, mashNeed: 22)
        XCTAssertEqual(unknown.tapsShort, 12)
        XCTAssertFalse(unknown.isNearMiss)
        XCTAssertTrue(unknown.isBigFish)
        XCTAssertTrue(unknown.isUndiscovered)
        XCTAssertEqual(unknown.displayName, "？？？")
        XCTAssertEqual(unknown.headline, "バラした…")
        XCTAssertEqual(unknown.subline, "あと12回足りなかった")

        let known = EscapeReport(kind: .lineBreak(rarity: .r, fishName: "アジ", imageName: "FishAji",
                                                  cm: 20, discovered: true), mashCount: 9, mashNeed: 10)
        XCTAssertEqual(known.displayName, "アジ")
        XCTAssertTrue(known.isNearMiss)
        XCTAssertFalse(known.isBigFish)
    }
}
