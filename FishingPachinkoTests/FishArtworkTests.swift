import XCTest
import SwiftUI
@testable import Dopagaki_Fishing_Collection

final class FishArtworkTests: XCTestCase {
    private var allFish: [FishSpec] {
        Rarity.allCases.flatMap { fishPool[$0] ?? [] } + secretFishPool
    }

    func testAllSpeciesHaveDistinctArtwork() {
        let expected = [
            "ワカサギ": "FishWakasagi", "メダカ": "FishMedaka", "ハゼ": "FishHaze",
            "アジ": "FishAji", "メバル": "FishMebaru", "サバ": "FishSaba",
            "シーバス": "FishSeabass", "マダイ": "FishMadai", "ブリ": "FishBuri",
            "ヒラマサ": "FishHiramasa", "カジキ": "FishKajiki", "キハダマグロ": "FishYellowfinTuna",
            "黄金龍魚": "FishGoldenDragonfish", "伝説の巨鯛": "FishLegendaryBream",
            "虹神クジラ": "FishRainbowWhale", "真夜中の星メダカ": "FishMidnightStarMedaka",
            "白銀の幻鮫": "FishSilverShark", "古代龍リュウグウノツカイ": "FishOarfish"
        ]
        XCTAssertEqual(allFish.count, 18)
        XCTAssertEqual(Set(allFish.map(\.imageName)).count, 18)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: allFish.map { ($0.name, $0.imageName) }), expected)
    }

    func testEveryIllustrationIsBundledAtFullResolution() throws {
        var encodedImages = Set<Data>()
        for fish in allFish {
            let image = try XCTUnwrap(UIImage(named: fish.imageName), fish.name)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1536, fish.name)
            XCTAssertEqual(cgImage.height, 1024, fish.name)
            encodedImages.insert(try XCTUnwrap(image.pngData()))
        }
        XCTAssertEqual(encodedImages.count, 18)
    }

    func testFishGameplayMetadataIsUnchanged() throws {
        let expected: [Rarity: [(String, ClosedRange<Int>, Int)]] = [
            .n: [("ワカサギ", 6...14, 100), ("メダカ", 3...8, 80), ("ハゼ", 8...15, 120)],
            .r: [("アジ", 15...35, 250), ("メバル", 15...30, 300), ("サバ", 25...45, 280)],
            .sr: [("シーバス", 50...90, 700), ("マダイ", 40...80, 900), ("ブリ", 60...110, 800)],
            .ssr: [("ヒラマサ", 100...180, 2200), ("カジキ", 200...350, 3000), ("キハダマグロ", 120...200, 2600)],
            .ur: [("黄金龍魚", 300...500, 6000), ("伝説の巨鯛", 150...250, 5000)],
            .lr: [("虹神クジラ", 800...1200, 15000)]
        ]
        for rarity in Rarity.allCases {
            let actual = try XCTUnwrap(fishPool[rarity])
            let metadata = try XCTUnwrap(expected[rarity])
            XCTAssertEqual(actual.count, metadata.count)
            for (fish, values) in zip(actual, metadata) {
                XCTAssertEqual(fish.name, values.0)
                XCTAssertEqual(fish.cm, values.1)
                XCTAssertEqual(fish.score, values.2)
            }
        }
        let secrets = [
            ("真夜中の星メダカ", 5...12, 4000), ("白銀の幻鮫", 250...420, 8000),
            ("古代龍リュウグウノツカイ", 450...700, 11000)
        ]
        XCTAssertEqual(secretFishPool.count, secrets.count)
        for (fish, values) in zip(secretFishPool, secrets) {
            XCTAssertEqual(fish.name, values.0)
            XCTAssertEqual(fish.cm, values.1)
            XCTAssertEqual(fish.score, values.2)
        }
    }

    @MainActor
    func testArtworkPreservesFullImageAspectRatioAtPhoneWidths() throws {
        for width: CGFloat in [84, 244, 316] {
            for fish in allFish {
                let renderer = ImageRenderer(
                    content: FishArtwork(imageName: fish.imageName, name: fish.name)
                        .frame(width: width))
                let image = try XCTUnwrap(renderer.uiImage, fish.name)
                XCTAssertEqual(image.size.width, width, accuracy: 1)
                XCTAssertEqual(image.size.height, width * 2 / 3, accuracy: 1)
            }
        }
    }

    @MainActor
    func testUncaughtRowsDoNotLeakNamesOrIllustrations() throws {
        let images = try allFish.map { fish -> Data in
            let content = FishDexRow(fish: fish, rarity: .n, secret: false, count: 0, maxCm: 0)
                .frame(width: 284)
                .background(.black)
            return try XCTUnwrap(ImageRenderer(content: content).uiImage?.pngData())
        }
        XCTAssertEqual(Set(images).count, 1, "Uncaught rows must be identical regardless of species")
    }

    @MainActor
    func testCaughtRowsShowDistinctIllustrationsAndFitPhoneWidths() throws {
        for width: CGFloat in [284, 357, 394] {
            var images = Set<Data>()
            for fish in allFish {
                let content = FishDexRow(fish: fish, rarity: .lr, secret: true, count: 123, maxCm: fish.cm.upperBound)
                    .frame(width: width)
                    .background(.black)
                let image = try XCTUnwrap(ImageRenderer(content: content).uiImage, fish.name)
                XCTAssertEqual(image.size.width, width)
                XCTAssertGreaterThanOrEqual(image.size.height, 68)
                images.insert(try XCTUnwrap(image.pngData()))
            }
            XCTAssertEqual(images.count, 18)
        }
    }

    @MainActor
    func testRevealCardsRenderAllSpeciesAtPhoneWidths() throws {
        for width: CGFloat in [320, 393, 430] {
            for fish in allFish {
                let rarity = Rarity.allCases.first { fishPool[$0]?.contains { $0.name == fish.name } == true } ?? .lr
                let caught = Caught(
                    name: fish.name, imageName: fish.imageName, rarity: rarity,
                    cm: fish.cm.upperBound, score: fish.score, medals: fish.score / 12,
                    perfect: true, isRecord: true, rushGain: rarity.rawValue >= Rarity.ur.rawValue ? 15 : 0,
                    isSmall: rarity.rawValue < Rarity.sr.rawValue,
                    isSecret: secretFishPool.contains { $0.name == fish.name })
                let cardWidth = min(width - 32, 360)
                let content = RevealCardContent(caught: caught)
                    .padding(22)
                    .frame(width: cardWidth)
                    .background(.black)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage, fish.name)
                XCTAssertEqual(image.size.width, cardWidth)
                XCTAssertGreaterThan(image.size.height, 350)
                if width == 393 && ["FishMadai", "FishRainbowWhale", "FishOarfish"].contains(fish.imageName) {
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "FishReveal-\(fish.imageName)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    @MainActor
    func testOverflowingRevealCardStartsAtTopAndCanScrollToBottom() async throws {
        let (window, scrollView) = try await revealScrollView(height: 320)
        defer { window.isHidden = true }

        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height + 50)
        XCTAssertEqual(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top, accuracy: 1)

        let bottomOffset =
            scrollView.contentSize.height - scrollView.bounds.height
            + scrollView.adjustedContentInset.bottom
        scrollView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: false)
        XCTAssertEqual(scrollView.contentOffset.y, bottomOffset, accuracy: 1)
        XCTAssertGreaterThan(scrollView.contentOffset.y, 50)
    }

    @MainActor
    func testRevealCardFillsViewportWhenContentFits() async throws {
        let (window, scrollView) = try await revealScrollView(height: 900)
        defer { window.isHidden = true }

        XCTAssertEqual(scrollView.contentSize.height, scrollView.bounds.height, accuracy: 1)
        XCTAssertEqual(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top, accuracy: 1)
    }

    @MainActor
    private func revealScrollView(height: CGFloat) async throws -> (UIWindow, UIScrollView) {
        let fish = try XCTUnwrap(secretFishPool.last)
        let caught = Caught(
            name: fish.name, imageName: fish.imageName, rarity: .lr,
            cm: fish.cm.upperBound, score: fish.score, medals: fish.score / 12,
            perfect: true, isRecord: true, rushGain: 15, isSmall: false, isSecret: true)
        let controller = UIHostingController(
            rootView: RevealCard(caught: caught).frame(width: 393, height: height))
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        controller.view.layoutIfNeeded()

        guard let scrollView = findScrollView(in: controller.view) else {
            window.isHidden = true
            XCTFail("Reveal card must contain a scroll view")
            throw NSError(domain: "FishArtworkTests", code: 1)
        }
        return (window, scrollView)
    }

    @MainActor
    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) { return scrollView }
        }
        return nil
    }
}
