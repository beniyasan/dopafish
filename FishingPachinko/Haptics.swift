import CoreHaptics
import UIKit

enum HapticCue: Equatable {
    case castRelease(power: Double)
    case lureLanded(big: Bool)
    case nibble
    case bite
    case cutIn(premium: Bool)
    case heartbeat(level: Int)          // reachKind 2 super / 3 golden / 4 rainbow
    case countdown(step: Int)           // 0 = "3", 1 = "2", 2 = "1"
    case surge(strong: Bool)
    case mashTap(progress: Double, closing: Bool)
    case hook
    case catchResult(Rarity)
    case rushIn(continued: Bool)
    case lastCast
    case lineSnap(nearMiss: Bool)
    case shortMiss
}

protocol HapticOutput: AnyObject {
    func play(_ cue: HapticCue)
}

/// 1イベント = transient（duration nil）または continuous
struct HapticEvent: Equatable {
    let time: Double
    let intensity: Float
    let sharpness: Float
    var duration: Double? = nil
}

enum HapticPatterns {
    static func events(for cue: HapticCue) -> [HapticEvent] {
        switch cue {
        case .castRelease(let power):
            let p = Float(min(1, max(0, power)))
            return [HapticEvent(time: 0, intensity: 0.35 + 0.5 * p, sharpness: 0.6),
                    HapticEvent(time: 0.02, intensity: 0.2 + 0.3 * p, sharpness: 0.3, duration: 0.12)]
        case .lureLanded(let big):
            return [HapticEvent(time: 0, intensity: big ? 0.6 : 0.35, sharpness: 0.2)]
        case .nibble:
            return [HapticEvent(time: 0, intensity: 0.25, sharpness: 0.7)]
        case .bite:
            return [HapticEvent(time: 0, intensity: 0.7, sharpness: 0.8),
                    HapticEvent(time: 0.12, intensity: 1.0, sharpness: 0.9)]
        case .cutIn(let premium):
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 1.0),
                    HapticEvent(time: 0.03, intensity: premium ? 0.9 : 0.6, sharpness: 0.3,
                                duration: premium ? 0.45 : 0.25)]
        case .heartbeat(let level):
            let l = Float(min(4, max(2, level)) - 2)          // 0...2
            let gap = 0.16 - 0.025 * Double(l)
            return [HapticEvent(time: 0, intensity: 0.65 + 0.15 * l, sharpness: 0.25),
                    HapticEvent(time: gap, intensity: 0.45 + 0.15 * l, sharpness: 0.2)]
        case .countdown(let step):
            let s = Float(min(2, max(0, step)))
            return [HapticEvent(time: 0, intensity: 0.7 + 0.15 * s, sharpness: 0.9),
                    HapticEvent(time: 0.02, intensity: 0.3 + 0.2 * s, sharpness: 0.4, duration: 0.1 + 0.05 * Double(s))]
        case .surge(let strong):
            return [HapticEvent(time: 0, intensity: strong ? 1.0 : 0.6, sharpness: strong ? 0.5 : 0.4,
                                duration: strong ? 0.25 : 0.12)]
        case .mashTap(let progress, let closing):
            let p = Float(min(1, max(0, progress)))
            return [HapticEvent(time: 0, intensity: closing ? 1.0 : 0.35 + 0.5 * p,
                                sharpness: closing ? 1.0 : 0.5 + 0.3 * p)]
        case .hook:
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 0.7),
                    HapticEvent(time: 0.02, intensity: 0.8, sharpness: 0.3, duration: 0.2)]
        case .catchResult(let rarity):
            return catchEvents(rarity)
        case .rushIn(let continued):
            let rise = HapticEvent(time: 0, intensity: 0.5, sharpness: 0.3, duration: continued ? 0.3 : 0.6)
            let beats = (0..<(continued ? 3 : 5)).map { i in
                HapticEvent(time: (continued ? 0.3 : 0.6) + 0.1 * Double(i), intensity: 1.0, sharpness: 0.9)
            }
            return [rise] + beats
        case .lastCast:
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 1.0),
                    HapticEvent(time: 0.03, intensity: 0.7, sharpness: 0.2, duration: 0.35)]
        case .lineSnap(let nearMiss):
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 1.0),
                    HapticEvent(time: 0.04, intensity: nearMiss ? 0.8 : 0.5, sharpness: 0.1,
                                duration: nearMiss ? 0.6 : 0.35)]
        case .shortMiss:
            return [HapticEvent(time: 0, intensity: 0.5, sharpness: 0.6),
                    HapticEvent(time: 0.1, intensity: 0.3, sharpness: 0.3)]
        }
    }

    private static func catchEvents(_ rarity: Rarity) -> [HapticEvent] {
        switch rarity {
        case .n, .r:
            return [HapticEvent(time: 0, intensity: rarity == .n ? 0.35 : 0.5, sharpness: 0.5)]
        case .sr:
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 0.6),
                    HapticEvent(time: 0.02, intensity: 0.6, sharpness: 0.3, duration: 0.25)]
        case .ssr:
            return [HapticEvent(time: 0, intensity: 1.0, sharpness: 0.7),
                    HapticEvent(time: 0.02, intensity: 0.8, sharpness: 0.3, duration: 0.6),
                    HapticEvent(time: 0.7, intensity: 1.0, sharpness: 0.9)]
        case .ur, .lr:
            let long = rarity == .lr
            let rumble = HapticEvent(time: 0, intensity: long ? 1.0 : 0.85, sharpness: 0.2, duration: long ? 1.2 : 0.8)
            let start = long ? 1.25 : 0.85
            let beats = (0..<(long ? 8 : 5)).map { i in
                HapticEvent(time: start + 0.09 * Double(i), intensity: 1.0, sharpness: 1.0)
            }
            return [rumble] + beats
        }
    }

    static func duration(of events: [HapticEvent]) -> Double {
        events.map { $0.time + ($0.duration ?? 0) }.max() ?? 0
    }
}

final class HapticEngine: HapticOutput {
    static let shared = HapticEngine()
    static let enabledKey = "hapticsEnabled"

    var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Self.enabledKey)
            if !enabled { engine?.stop(completionHandler: nil); engineRunning = false }
        }
    }

    private let defaults: UserDefaults
    private let supportsCore = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var engineRunning = false
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notifier = UINotificationFeedbackGenerator()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        if supportsCore { makeEngine() }
        [lightImpact, mediumImpact, heavyImpact].forEach { $0.prepare() }
    }

    func play(_ cue: HapticCue) {
        guard enabled else { return }
        if supportsCore, playCore(HapticPatterns.events(for: cue)) { return }
        playFallback(cue)
    }

    private func makeEngine() {
        guard let engine = try? CHHapticEngine() else { return }
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        engine.stoppedHandler = { [weak self] _ in DispatchQueue.main.async { self?.engineRunning = false } }
        engine.resetHandler = { [weak self] in DispatchQueue.main.async { self?.engineRunning = false } }
        self.engine = engine
    }

    private func playCore(_ events: [HapticEvent]) -> Bool {
        guard let engine else { return false }
        do {
            if !engineRunning {
                try engine.start()
                engineRunning = true
            }
            let chEvents = events.map { e -> CHHapticEvent in
                let params = [CHHapticEventParameter(parameterID: .hapticIntensity, value: e.intensity),
                              CHHapticEventParameter(parameterID: .hapticSharpness, value: e.sharpness)]
                if let d = e.duration {
                    return CHHapticEvent(eventType: .hapticContinuous, parameters: params,
                                         relativeTime: e.time, duration: d)
                }
                return CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: e.time)
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: chEvents, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engineRunning = false
            return false
        }
    }

    private func playFallback(_ cue: HapticCue) {
        switch cue {
        case .nibble, .lureLanded(big: false), .mashTap(_, closing: false):
            lightImpact.impactOccurred(); lightImpact.prepare()
        case .castRelease, .lureLanded, .bite, .shortMiss, .surge(strong: false), .heartbeat(level: 2):
            mediumImpact.impactOccurred(); mediumImpact.prepare()
        case .catchResult(let r):
            if r.rawValue >= Rarity.sr.rawValue { notifier.notificationOccurred(.success) }
            else { notifier.notificationOccurred(.warning) }
        case .rushIn:
            notifier.notificationOccurred(.success)
        case .lineSnap:
            notifier.notificationOccurred(.error)
        default:
            heavyImpact.impactOccurred(); heavyImpact.prepare()
        }
    }
}
