import XCTest
import SwiftUI
@testable import Dopagaki_Fishing_Collection

final class RevealCardFXTests: XCTestCase {
    private func caught(_ rarity: Rarity, isSecret: Bool = false) -> Caught {
        Caught(name: "テスト魚", imageName: "FishMadai", rarity: rarity,
               cm: 50, score: 100, medals: 8, perfect: false, isRecord: false,
               rushGain: 0, isSmall: rarity.rawValue <= Rarity.r.rawValue,
               isSecret: isSecret)
    }

    func testTierFollowsRarity() {
        XCTAssertEqual(CardFXSpec.forCatch(caught(.n)).tier, 0)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.r)).tier, 0)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.sr)).tier, 1)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.ssr)).tier, 2)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.ur)).tier, 3)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.lr)).tier, 4)
    }

    func testFlashinessIsMonotonicWithTier() {
        let specs = [Rarity.n, .r, .sr, .ssr, .ur, .lr].map { CardFXSpec.forCatch(caught($0)) }
        for pair in zip(specs, specs.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1.rayCount, pair.0.rayCount)
            XCTAssertGreaterThanOrEqual(pair.1.sparkleCount, pair.0.sparkleCount)
            XCTAssertGreaterThanOrEqual(pair.1.ringCount, pair.0.ringCount)
            XCTAssertGreaterThanOrEqual(pair.1.border, pair.0.border)
            XCTAssertGreaterThanOrEqual(pair.1.dimOpacity, pair.0.dimOpacity)
        }
    }

    func testSmallFishStaySubdued() {
        // N/R は拍子抜けのハズレ相当 — 静かなカードのまま
        for rarity in [Rarity.n, .r] {
            let spec = CardFXSpec.forCatch(caught(rarity))
            XCTAssertEqual(spec.tier, 0)
            XCTAssertEqual(spec.rayCount, 0)
            XCTAssertEqual(spec.sparkleCount, 0)
            XCTAssertEqual(spec.ringCount, 0)
            XCTAssertFalse(spec.entryFlash)
            XCTAssertFalse(spec.entryShine)
            XCTAssertEqual(spec.border, .plain)
            XCTAssertFalse(spec.labelPulse)
            XCTAssertFalse(spec.hueCycle)
        }
    }

    func testSecretCatchGetsShowtimeFloor() {
        // 幻魚はどのレア帯で釣れても最低SSR級の演出
        for rarity in [Rarity.n, .r, .sr, .ssr] {
            XCTAssertGreaterThanOrEqual(CardFXSpec.forCatch(caught(rarity, isSecret: true)).tier, 2)
        }
        XCTAssertEqual(CardFXSpec.forCatch(caught(.ur, isSecret: true)).tier, 3)
        XCTAssertEqual(CardFXSpec.forCatch(caught(.lr, isSecret: true)).tier, 4)
    }

    func testTopRaritySignatures() {
        let ur = CardFXSpec.forCatch(caught(.ur))
        XCTAssertEqual(ur.border, .shimmer)
        XCTAssertGreaterThan(ur.ringCount, 0)
        XCTAssertGreaterThan(ur.rayCount, 0)
        XCTAssertFalse(ur.hueCycle)

        let lr = CardFXSpec.forCatch(caught(.lr))
        XCTAssertEqual(lr.border, .rainbow)
        XCTAssertTrue(lr.hueCycle)
        XCTAssertTrue(lr.rayRainbow)
        XCTAssertGreaterThan(lr.ringCount, ur.ringCount)
        XCTAssertGreaterThan(lr.entryDelay, ur.entryDelay)
    }

    func testEveryTierKeepsTheCardReadable() {
        // 掃射・光・リングはカードの外周と背景に限定 — 仕様上ここは変えない
        for rarity in Rarity.allCases {
            let spec = CardFXSpec.forCatch(caught(rarity))
            XCTAssertLessThan(spec.dimOpacity, 0.75)
            XCTAssertLessThanOrEqual(spec.entryDelay, 0.3)
        }
    }

    @MainActor
    func testRevealCardBuildsForEveryRarity() throws {
        // 各ティアの演出Viewが実際に構築・描画できること
        for rarity in Rarity.allCases {
            let card = RevealCard(caught: caught(rarity))
                .frame(width: 393, height: 700)
            let image = try XCTUnwrap(ImageRenderer(content: card).uiImage, "\(rarity)")
            XCTAssertEqual(image.size.width, 393)
        }
    }
}
