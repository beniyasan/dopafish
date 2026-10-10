import XCTest
@testable import Dopagaki_Fishing_Collection

private final class HapticSpy: HapticOutput {
    var cues: [HapticCue] = []
    func play(_ cue: HapticCue) { cues.append(cue) }
}

final class HapticsTests: XCTestCase {
    private var spy: HapticSpy!

    override func setUp() {
        super.setUp()
        SoundEngine.shared.muted = true
        spy = HapticSpy()
    }

    private func freshModel() -> GameModel {
        let model = GameModel()
        model.rareLv = 3
        model.reelLv = 0
        model.phase = .idle
        model.haptics = spy
        return model
    }

    private func castToReach(_ model: GameModel) {
        model.pressCast()
        model.releaseCast()
        for _ in 0..<400 where model.phase != .reach { model.tick(0.05) }
        XCTAssertEqual(model.phase, .reach)
    }

    private func castToMash(_ model: GameModel, result: Rarity) {
        castToReach(model)
        model.result = result
        for _ in 0..<400 where model.phase != .mash { model.tick(0.05) }
        XCTAssertEqual(model.phase, .mash)
    }

    private func peak(_ cue: HapticCue) -> Float {
        HapticPatterns.events(for: cue).map(\.intensity).max() ?? 0
    }

    private func length(_ cue: HapticCue) -> Double {
        HapticPatterns.duration(of: HapticPatterns.events(for: cue))
    }

    private func mashTaps() -> [(Double, Bool)] {
        spy.cues.compactMap {
            if case let .mashTap(progress, closing) = $0 { return (progress, closing) }
            return nil
        }
    }

    // MARK: patterns

    func testAllPatternsStayWithinCoreHapticsRanges() {
        var cues: [HapticCue] = [.castRelease(power: 0), .castRelease(power: 1), .lureLanded(big: false),
                                 .lureLanded(big: true), .nibble, .bite, .cutIn(premium: false),
                                 .cutIn(premium: true), .surge(strong: false), .surge(strong: true),
                                 .mashTap(progress: 0, closing: false), .mashTap(progress: 1, closing: true),
                                 .hook, .rushIn(continued: false), .rushIn(continued: true), .lastCast,
                                 .lineSnap(nearMiss: false), .lineSnap(nearMiss: true), .shortMiss]
        cues += (2...4).map { .heartbeat(level: $0) }
        cues += (0...2).map { .countdown(step: $0) }
        cues += Rarity.allCases.map { .catchResult($0) }
        for cue in cues {
            let events = HapticPatterns.events(for: cue)
            XCTAssertFalse(events.isEmpty, "\(cue)")
            for e in events {
                XCTAssertTrue((0...1).contains(e.intensity), "\(cue)")
                XCTAssertTrue((0...1).contains(e.sharpness), "\(cue)")
                XCTAssertGreaterThanOrEqual(e.time, 0, "\(cue)")
                if let d = e.duration { XCTAssertGreaterThan(d, 0, "\(cue)") }
            }
            XCTAssertLessThanOrEqual(HapticPatterns.duration(of: events), 2.0, "\(cue)")
        }
    }

    func testCatchPatternsEscalateWithRarity() {
        let tiers = Rarity.allCases.map { HapticCue.catchResult($0) }
        for (lo, hi) in zip(tiers, tiers.dropFirst()) {
            XCTAssertLessThanOrEqual(peak(lo), peak(hi), "\(lo) → \(hi)")
            XCTAssertLessThanOrEqual(length(lo), length(hi), "\(lo) → \(hi)")
        }
        XCTAssertLessThan(length(.catchResult(.ssr)), length(.catchResult(.ur)))
        XCTAssertLessThan(length(.catchResult(.ur)), length(.catchResult(.lr)))
        XCTAssertLessThan(peak(.catchResult(.n)), peak(.catchResult(.sr)))
    }

    func testReachHeartbeatCountdownAndMashGetStronger() {
        XCTAssertLessThan(peak(.heartbeat(level: 2)), peak(.heartbeat(level: 3)))
        XCTAssertLessThan(peak(.heartbeat(level: 3)), peak(.heartbeat(level: 4)))
        XCTAssertLessThan(peak(.countdown(step: 0)), peak(.countdown(step: 2)))
        XCTAssertLessThan(peak(.mashTap(progress: 0, closing: false)), peak(.mashTap(progress: 0.8, closing: false)))
        XCTAssertLessThan(peak(.mashTap(progress: 0.8, closing: false)), peak(.mashTap(progress: 0.8, closing: true)))
        XCTAssertLessThan(peak(.castRelease(power: 0.35)), peak(.castRelease(power: 1)))
        XCTAssertLessThan(length(.lineSnap(nearMiss: false)), length(.lineSnap(nearMiss: true)))
        XCTAssertLessThan(length(.rushIn(continued: true)), length(.rushIn(continued: false)))
    }

    // MARK: game flow

    func testCatchFlowPlaysCastLandBiteMashHookAndRarityCue() {
        let model = freshModel()
        castToMash(model, result: .sr)
        XCTAssertTrue(spy.cues.contains { if case .castRelease = $0 { return true }; return false })
        XCTAssertTrue(spy.cues.contains { if case .lureLanded = $0 { return true }; return false })
        XCTAssertTrue(spy.cues.contains(.bite))
        XCTAssertFalse(spy.cues.contains(.lastCast))

        for _ in 0..<14 { model.tapScreen() }      // SR mashNeed = 14
        let taps = mashTaps()
        XCTAssertEqual(taps.count, 14)
        XCTAssertEqual(taps.filter(\.1).count, 5, "残り5〜1回の5打だけ強い振動")
        XCTAssertFalse(taps[7].1)
        XCTAssertTrue(taps[8].1)
        XCTAssertLessThan(taps[0].0, taps[7].0)
        XCTAssertEqual(spy.cues.last, .hook)

        model.tick(0.6)
        XCTAssertEqual(model.phase, .reveal)
        XCTAssertEqual(spy.cues.last, .catchResult(.sr))
        XCTAssertEqual(spy.cues.filter { if case .catchResult = $0 { return true }; return false }.count, 1)
    }

    func testBluffMashTapsNeverUseClosingCue() {
        let model = freshModel()
        castToReach(model)
        model.result = nil
        for _ in 0..<400 where model.phase == .reach { model.tick(0.05) }
        guard model.phase == .mash else { return }   // 短いリーチのハズレは連打なし
        for _ in 0..<40 { model.tapScreen() }
        XCTAssertFalse(mashTaps().contains { $0.1 })
    }

    func testLineBreakSnapIsStrongerForNearMiss() {
        let near = freshModel()
        castToMash(near, result: .ssr)
        for _ in 0..<15 { near.tapScreen() }        // 18回中15回 → あと3回
        for _ in 0..<200 where near.phase == .mash { near.tick(0.05) }
        XCTAssertEqual(near.phase, .escaping)
        XCTAssertEqual(spy.cues.last, .lineSnap(nearMiss: true))

        spy.cues = []
        let far = freshModel()
        castToMash(far, result: .ssr)
        for _ in 0..<200 where far.phase == .mash { far.tick(0.05) }
        XCTAssertEqual(spy.cues.last, .lineSnap(nearMiss: false))
    }

    func testShortReachMissPlaysShortMiss() {
        for _ in 0..<60 {
            spy.cues = []
            let model = freshModel()
            castToReach(model)
            guard model.reachKind <= 1 else { continue }
            model.result = nil
            for _ in 0..<400 where model.phase == .reach { model.tick(0.05) }
            XCTAssertEqual(model.phase, .escaping)
            XCTAssertNil(model.escapeReport)
            XCTAssertEqual(spy.cues.last, .shortMiss)
            return
        }
        XCTFail("短いリーチが一度も出なかった")
    }

    private func enterRush(_ model: GameModel, gain: Int) {
        model.phase = .reveal
        model.reveal = Caught(name: "テスト魚", imageName: "FishMadai", rarity: .ur, cm: 50, score: 100,
                              medals: 8, perfect: false, isRecord: false, rushGain: gain, isSmall: false)
        model.dismissReveal()
        model.tick(2.21)
        XCTAssertEqual(model.phase, .idle)
    }

    func testRushEntryContinueAndLastCast() {
        let model = freshModel()
        enterRush(model, gain: 1)
        XCTAssertTrue(spy.cues.contains(.rushIn(continued: false)))
        enterRush(model, gain: 1)
        XCTAssertTrue(spy.cues.contains(.rushIn(continued: true)))
        XCTAssertEqual(model.rushLeft, 2)

        spy.cues = []
        model.pressCast(); model.releaseCast()
        XCTAssertEqual(model.rushLeft, 1)
        XCTAssertTrue(spy.cues.contains { if case .castRelease = $0 { return true }; return false })
        XCTAssertFalse(spy.cues.contains(.lastCast))

        let last = freshModel()
        enterRush(last, gain: 1)
        spy.cues = []
        last.pressCast(); last.releaseCast()
        XCTAssertEqual(last.rushLeft, 0)
        XCTAssertEqual(spy.cues, [.lastCast])
    }

    // MARK: setting

    func testEnabledSettingPersists() throws {
        let suite = "HapticsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(HapticEngine(defaults: defaults).enabled)
        let engine = HapticEngine(defaults: defaults)
        engine.enabled = false
        engine.play(.bite)
        XCTAssertFalse(HapticEngine(defaults: defaults).enabled)
    }
}
