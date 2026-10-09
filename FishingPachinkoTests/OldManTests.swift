import XCTest
import SwiftUI
@testable import Dopagaki_Fishing_Collection

final class OldManTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SoundEngine.shared.muted = true
    }

    func testHeatSelectsPortraitAndPresentation() {
        for heat in OldManCue.Heat.allCases {
            let cutIn = heat == .hot || heat == .premium
            XCTAssertEqual(heat.isCutIn, cutIn)
            XCTAssertEqual(heat.imageName, cutIn ? "OldManHot" : "OldManNormal")
            XCTAssertEqual(heat.duration, cutIn ? 3.6 : 2.8)
        }
    }

    func testNormalConversationExpires() {
        let model = GameModel()
        model.phase = .waiting
        model.showOldMan("お、いい天気だな")
        model.tick(2.7)
        XCTAssertNotNil(model.oldManCue)
        model.tick(0.11)
        XCTAssertNil(model.oldManCue)
    }

    func testCutInHasLongerLifetime() {
        let model = GameModel()
        model.phase = .waiting
        model.showOldMan("…大物の気配がする", heat: .hot)
        model.tick(2.9)
        XCTAssertEqual(model.oldManCue?.heat, .hot)
        model.tick(0.71)
        XCTAssertNil(model.oldManCue)
    }

    func testRepeatedLineDoesNotExpireNewCueEarly() {
        let model = GameModel()
        model.phase = .waiting
        model.showOldMan("お、いい天気だな")
        let firstID = model.oldManCue?.id
        model.tick(1)
        model.showOldMan("お、いい天気だな")
        XCTAssertNotEqual(model.oldManCue?.id, firstID)
        model.tick(1.81)
        XCTAssertNotNil(model.oldManCue)
        model.tick(1)
        XCTAssertNil(model.oldManCue)
    }

    func testAmbientConversationCannotReplaceCutIn() {
        let model = GameModel()
        model.phase = .waiting
        model.showOldMan("……あれは、伝説のヤツだ", heat: .premium)
        let id = model.oldManCue?.id
        model.showOldMan("そろそろ帰るか…")
        model.showOldMan("ウキの動きが良いぞ", heat: .warm)
        XCTAssertEqual(model.oldManCue?.id, id)
        XCTAssertEqual(model.oldManCue?.heat, .premium)
    }

    func testCueCannotInterruptInteractiveOrResultPhases() {
        for phase: Phase in [.title, .charging, .flying, .mash, .reveal, .escaping, .rushEnding] {
            let model = GameModel()
            model.phase = phase
            model.showOldMan("…大物の気配がする", heat: .hot)
            XCTAssertNil(model.oldManCue)
            XCTAssertEqual(model.phase, phase)
        }
    }

    func testBothPortraitsAreBundledWithTransparency() throws {
        for name in ["OldManNormal", "OldManHot"] {
            let image = try XCTUnwrap(UIImage(named: name))
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1024)
            XCTAssertEqual(cgImage.height, 1536)
            XCTAssertNotEqual(cgImage.alphaInfo, .none)
            XCTAssertNotEqual(cgImage.alphaInfo, .noneSkipFirst)
            XCTAssertNotEqual(cgImage.alphaInfo, .noneSkipLast)
        }
    }

    @MainActor
    func testCalloutsAndCutInsRenderAtPhoneWidths() throws {
        for width: CGFloat in [320, 393, 430] {
            for heat in OldManCue.Heat.allCases {
                let cue = OldManCue(line: heat == .premium
                    ? "50年で2度しか見てないぞ、あれを"
                    : "静かすぎる…何か来るぞ", heat: heat)
                let content = Group {
                    if heat.isCutIn {
                        OldManCutIn(cue: cue)
                    } else {
                        OldManCallout(cue: cue)
                    }
                }
                .padding(12)
                .frame(width: width)
                .background(Color(red: 0.08, green: 0.28, blue: 0.38))
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, width)
                XCTAssertGreaterThan(image.size.height, 100)
                if width == 393 {
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "OldMan-\(heat)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
