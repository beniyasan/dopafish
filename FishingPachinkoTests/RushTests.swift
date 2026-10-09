import XCTest
import SwiftUI
@testable import Dopagaki_Fishing_Collection

final class RushTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SoundEngine.shared.muted = true
    }

    private func caught(_ rarity: Rarity, gain: Int) -> Caught {
        Caught(name: "テスト魚", imageName: "FishMadai", rarity: rarity,
               cm: 50, score: 100, medals: 8, perfect: false, isRecord: false,
               rushGain: gain, isSmall: rarity.rawValue <= Rarity.r.rawValue)
    }

    private func startRush(spins: Int = 10) -> GameModel {
        let model = GameModel()
        model.rareLv = 3
        model.reelLv = 0
        model.phase = .reveal
        model.score = 700
        model.reveal = caught(.ur, gain: spins)
        model.dismissReveal()
        model.tick(2.21)
        XCTAssertEqual(model.phase, .idle)
        return model
    }

    private func cast(_ model: GameModel) {
        model.pressCast()
        model.releaseCast()
        XCTAssertEqual(model.phase, .flying)
    }

    private func castToMash(_ model: GameModel) {
        cast(model)
        for _ in 0..<400 {
            if model.phase == .mash { break }
            model.tick(0.05)
        }
        XCTAssertEqual(model.phase, .mash)
    }

    func testCountdownDistinguishesLastCastFromRemainingOne() {
        for spins in [15, 4] {
            let status = RushStatus(remaining: spins)
            XCTAssertFalse(status.isUrgent)
            XCTAssertFalse(status.isLast)
            XCTAssertEqual(status.heading, "RUSH")
        }
        for spins in [3, 2, 1] {
            let status = RushStatus(remaining: spins)
            XCTAssertTrue(status.isUrgent)
            XCTAssertFalse(status.isLast)
        }
        let last = RushStatus(remaining: 0)
        XCTAssertTrue(last.isLast)
        XCTAssertTrue(last.isUrgent)
        XCTAssertEqual(last.heading, "LAST CAST")
        XCTAssertTrue(last.hint.contains("最終回転"))
    }

    func testCastConsumesExactlyOneAndLastCastStaysHighProbability() {
        let model = startRush(spins: 1)
        cast(model)
        XCTAssertEqual(model.rushLeft, 0)
        XCTAssertTrue(model.rushActive)
        XCTAssertTrue(model.rushStatus.isLast)
        XCTAssertEqual(model.rarityForRoll(0.66), .ssr)
        XCTAssertEqual(model.rarityForRoll(0.18), .n)
        model.releaseCast()
        model.pressCast()
        XCTAssertEqual(model.rushLeft, 0)
        model.tick(0.46)
        XCTAssertTrue(model.rushActive)
        XCTAssertNil(model.rushSummary)
        XCTAssertEqual(model.phase, .waiting)
    }

    func testRushGainTableIsUnchanged() {
        for level in 0...5 {
            for rarity in [Rarity.n, .r, .sr] {
                XCTAssertEqual(RushRules.gain(for: rarity, active: true, rushLevel: level), 0)
            }
            XCTAssertEqual(RushRules.gain(for: .ssr, active: false, rushLevel: level), 0)
            XCTAssertEqual(RushRules.gain(for: .ssr, active: true, rushLevel: level), 2 + level)
            XCTAssertEqual(RushRules.gain(for: .ur, active: false, rushLevel: level), 10 + level)
            XCTAssertEqual(RushRules.gain(for: .lr, active: false, rushLevel: level), 15 + level)
            XCTAssertEqual(RushRules.gain(for: .ur, active: true, rushLevel: level), 12 + level)
            XCTAssertEqual(RushRules.gain(for: .lr, active: true, rushLevel: level), 17 + level)
        }
    }

    func testBonusRateKnownValuesAndEquipmentCaps() {
        for reel in 0...5 {
            XCTAssertEqual(RushRules.bonusProbability(rareLevel: 0, reelLevel: reel), 0)
        }
        XCTAssertEqual(RushRules.bonusProbability(rareLevel: 1, reelLevel: 0),
                       0.34 / 0.92, accuracy: 1e-12)
        XCTAssertEqual(RushRules.bonusProbability(rareLevel: 1, reelLevel: 5),
                       0.34 / 0.92 + 0.10 / 0.92 * 0.75 * 0.34 / (0.82 * 0.5),
                       accuracy: 1e-12)
        XCTAssertEqual(RushRules.bonusProbability(rareLevel: 5, reelLevel: 5),
                       0.34 / 0.60, accuracy: 1e-12)
    }

    func testBonusRateMatchesActualTableForEveryEquipmentCombination() {
        let model = GameModel()
        model.rushActive = true
        let samples = 10_000
        for rare in 0...5 {
            let cap = RushRules.rarityCap(rareLevel: rare)
            for reel in 0...5 {
                var direct = 0.0
                var misses = 0.0
                var rescued = 0.0
                for i in 0..<samples {
                    let u = (Double(i) + 0.5) / Double(samples)
                    if let rarity = model.rarityForRoll(RushRules.boost(u, rareLevel: rare)) {
                        if min(rarity.rawValue, cap.rawValue) >= Rarity.ssr.rawValue { direct += 1 }
                    } else {
                        misses += 1
                    }
                    let reroll = RushRules.missThreshold + u * (1 - RushRules.missThreshold)
                    if let rarity = model.rarityForRoll(RushRules.reelBoost(reroll, reelLevel: reel)),
                       min(rarity.rawValue, cap.rawValue) >= Rarity.ssr.rawValue {
                        rescued += 1
                    }
                }
                let n = Double(samples)
                let measured = direct / n + misses / n * 0.15 * Double(reel) * rescued / n
                XCTAssertEqual(RushRules.bonusProbability(rareLevel: rare, reelLevel: reel),
                               measured, accuracy: 0.0002, "竿\(rare) / リール\(reel)")
            }
        }
    }

    func testFinalCatchEndsOnlyAfterCardAndSummaryExcludesEntryCatch() {
        let model = startRush(spins: 1)
        castToMash(model)
        model.score += 200
        model.phase = .reveal
        model.reveal = caught(.n, gain: 0)
        XCTAssertTrue(model.rushActive)
        XCTAssertNil(model.rushSummary)
        model.dismissReveal()
        XCTAssertEqual(model.phase, .rushEnding)
        XCTAssertFalse(model.rushActive)
        XCTAssertEqual(model.rushSummary?.casts, 1)
        XCTAssertEqual(model.rushSummary?.score, 200)
        model.tick(RushRules.endingDuration - 0.01)
        XCTAssertEqual(model.phase, .rushEnding)
        model.tick(0.02)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.rushSummary)
        XCTAssertEqual(model.rarityForRoll(0.66), .r)
    }

    func testFinalMissAlsoShowsSummary() {
        let model = startRush(spins: 1)
        castToMash(model)
        model.tick(10)
        XCTAssertEqual(model.phase, .escaping)
        XCTAssertTrue(model.rushActive)
        model.tick(1.31)
        XCTAssertEqual(model.phase, .rushEnding)
        XCTAssertEqual(model.rushSummary?.casts, 1)
        XCTAssertEqual(model.rushSummary?.score, 0)
    }

    func testFinalCastBonusRescuesRushWithoutEndingOrDuplicateAwards() {
        let model = startRush(spins: 1)
        castToMash(model)
        model.phase = .reveal
        model.reveal = caught(.ssr, gain: 2)
        model.dismissReveal()
        XCTAssertEqual(model.rushLeft, 2)
        model.dismissReveal()
        XCTAssertEqual(model.rushLeft, 2)
        model.tick(2.21)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(model.rushActive)
        XCTAssertNil(model.rushSummary)
        XCTAssertFalse(model.rushStatus.isLast)
    }

    func testSummaryAccumulatesAcrossExtensionButResetsOnNewRush() {
        let model = startRush(spins: 1)
        castToMash(model)
        model.score += 200
        model.phase = .reveal
        model.reveal = caught(.ssr, gain: 1)
        model.dismissReveal()
        model.tick(2.21)
        castToMash(model)
        model.score += 300
        model.phase = .reveal
        model.reveal = caught(.n, gain: 0)
        model.dismissReveal()
        XCTAssertEqual(model.rushSummary?.casts, 2)
        XCTAssertEqual(model.rushSummary?.score, 500)
        model.dismissRushSummary()
        model.phase = .reveal
        model.score += 1_000
        model.reveal = caught(.ur, gain: 1)
        model.dismissReveal()
        model.tick(2.21)
        castToMash(model)
        model.phase = .reveal
        model.reveal = caught(.n, gain: 0)
        model.dismissReveal()
        XCTAssertEqual(model.rushSummary?.casts, 1)
        XCTAssertEqual(model.rushSummary?.score, 0)
    }

    func testAutoWaitsForSummaryThenResumesOnce() {
        for tapToClose in [false, true] {
            let model = startRush(spins: 1)
            castToMash(model)
            model.autoCast = true
            model.phase = .reveal
            model.reveal = caught(.n, gain: 0)
            model.dismissReveal()
            model.tick(1.01)
            XCTAssertEqual(model.phase, .rushEnding)
            model.pressCast()
            XCTAssertEqual(model.phase, .rushEnding)
            if tapToClose {
                model.tapScreen()
                model.dismissRushSummary()
            } else {
                model.tick(1.4)
            }
            XCTAssertEqual(model.phase, .idle)
            model.tick(0.99)
            XCTAssertEqual(model.phase, .idle)
            model.tick(0.02)
            XCTAssertEqual(model.phase, .flying)
            XCTAssertFalse(model.rushActive)
            XCTAssertEqual(model.rushLeft, 0)
        }
    }

    @MainActor
    func testSummaryStopsBGMAndUnmutingDoesNotRestoreIt() throws {
        let sound = SoundEngine.shared
        sound.prepare()
        defer {
            sound.stopBGM()
            sound.muted = true
        }
        let model = startRush(spins: 1)
        castToMash(model)
        let oldPlayer = try XCTUnwrap(sound.bgmPlayer)
        model.phase = .reveal
        model.reveal = caught(.n, gain: 0)
        model.dismissReveal()
        XCTAssertEqual(model.phase, .rushEnding)
        XCTAssertNil(sound.bgmPlayer)
        sound.muted = false
        XCTAssertEqual(oldPlayer.volume, 0, accuracy: 0.001)
        let stopped = expectation(description: "Ending music stops after fading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertFalse(oldPlayer.isPlaying)
            XCTAssertNil(sound.bgmPlayer)
            stopped.fulfill()
        }
        wait(for: [stopped], timeout: 2)
    }

    @MainActor
    func testOldBGMFadeDoesNotStopNormalMusicAfterEarlyDismissal() throws {
        let sound = SoundEngine.shared
        sound.prepare()
        defer {
            sound.stopBGM()
            sound.muted = true
        }
        let model = startRush(spins: 1)
        castToMash(model)
        let oldPlayer = try XCTUnwrap(sound.bgmPlayer)
        model.phase = .reveal
        model.reveal = caught(.n, gain: 0)
        model.dismissReveal()
        model.tapScreen()
        let idlePlayer = try XCTUnwrap(sound.bgmPlayer)
        XCTAssertFalse(oldPlayer === idlePlayer)
        sound.muted = false
        XCTAssertEqual(idlePlayer.volume, 0.5, accuracy: 0.001)
        let stopped = expectation(description: "Only the previous music stops")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertFalse(oldPlayer.isPlaying)
            XCTAssertTrue(sound.bgmPlayer === idlePlayer)
            XCTAssertEqual(idlePlayer.volume, 0.5, accuracy: 0.001)
            stopped.fulfill()
        }
        wait(for: [stopped], timeout: 2)
    }

    #if DEBUG
    func testDebugRushRequiresBoundedPositiveSpinCount() {
        for args in [[], ["-rush"], ["-rush", "oops"], ["-rush", "0"],
                     ["-rush", "-1"], ["-rush", "100"]] {
            XCTAssertNil(RushRules.debugStartingSpins(arguments: args))
        }
        XCTAssertEqual(RushRules.debugStartingSpins(arguments: ["-rush", "1"]), 1)
        XCTAssertEqual(RushRules.debugStartingSpins(arguments: ["-rush", "99"]), 99)
    }
    #endif

    @MainActor
    func testRushHUDAndSummaryRenderAtPhoneWidths() throws {
        for width: CGFloat in [320, 375, 393, 430] {
            for remaining in [15, 3, 1, 0] {
                let view = RushHUD(status: RushStatus(remaining: remaining), bonusProbability: 0.47)
                    .frame(width: width)
                let image = try XCTUnwrap(ImageRenderer(content: view).uiImage)
                XCTAssertEqual(image.size.width, width)
                XCTAssertLessThan(image.size.height, 140)
            }
            let summary = RushEndView(summary: RushSummary(casts: 123, score: 1_234_567),
                                      onContinue: {})
                .frame(width: width, height: 568)
            let image = try XCTUnwrap(ImageRenderer(content: summary).uiImage)
            XCTAssertEqual(image.size.width, width)
            XCTAssertEqual(image.size.height, 568)
        }
    }
}
