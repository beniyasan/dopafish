import Foundation
import AVFoundation
import UIKit

// MARK: - WAV synthesis
// All audio is generated in code — no bundled assets.
// Renders 16-bit PCM mono WAV into tmp files, played with AVAudioPlayer.

enum Wave { case sine, square, saw, tri, noise }

final class Synth {
    let sr: Double
    var buf: [Float]
    private var noiseState: UInt32 = 0x2f6e2b1

    init(sampleRate: Double = 44100, seconds: Double) {
        sr = sampleRate
        buf = [Float](repeating: 0, count: Int(sampleRate * seconds))
    }

    private func osc(_ w: Wave, _ f: Double, _ t: Double) -> Float {
        switch w {
        case .sine:   return Float(sin(2 * .pi * f * t))
        case .square: return sin(2 * .pi * f * t) >= 0 ? 1 : -1
        case .saw:    return Float(2 * (f * t).truncatingRemainder(dividingBy: 1) - 1)
        case .tri:    return Float(2 * abs(2 * (f * t).truncatingRemainder(dividingBy: 1) - 1) - 1)
        case .noise:
            noiseState = noiseState &* 1664525 &+ 1013904223
            return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
        }
    }

    /// Add a tone: frequency may glide f0->f1, ADSR-lite envelope.
    func add(at t0: Double, dur: Double, wave: Wave = .sine, f0: Double, f1: Double? = nil,
             gain: Float = 0.5, attack: Double = 0.005, decay: Double = -1, lpf: Bool = false) {
        let dec = decay >= 0 ? decay : dur
        let s0 = Int(t0 * sr), s1 = min(buf.count, s0 + Int(dur * sr))
        var last: Float = 0
        for i in s0..<s1 {
            let t = Double(i - s0) / sr
            let x = t / dur
            let f = f0 + ((f1 ?? f0) - f0) * x
            var s = osc(wave, f, t)
            if lpf { s = (s + last) * 0.5; last = s }
            let a = min(1, t / max(attack, 0.0001))
            let d = max(0, 1 - max(0, t - (dur - dec)) / dec)
            buf[i] += s * gain * Float(a * d)
        }
    }

    /// Drum-ish noise burst with fast decay.
    func hit(at t0: Double, dur: Double = 0.08, wave: Wave = .noise, f: Double = 3000,
             gain: Float = 0.5, decay: Double = 0.05) {
        add(at: t0, dur: dur, wave: wave, f0: f, f1: f * 0.5, gain: gain, attack: 0.001, decay: decay, lpf: true)
    }

    func wavData() -> Data {
        var out = Data()
        let n = buf.count
        let byteRate = UInt32(sr * 2), dataSize = UInt32(n * 2)
        func w32(_ v: UInt32) { out.append(UInt8(v & 255)); out.append(UInt8(v >> 8 & 255)); out.append(UInt8(v >> 16 & 255)); out.append(UInt8(v >> 24 & 255)) }
        func w16(_ v: UInt16) { out.append(UInt8(v & 255)); out.append(UInt8(v >> 8 & 255)) }
        out.append(contentsOf: "RIFF".utf8); w32(36 + dataSize); out.append(contentsOf: "WAVE".utf8)
        out.append(contentsOf: "fmt ".utf8); w32(16); w16(1); w16(1)
        w32(UInt32(sr)); w32(byteRate); w16(2); w16(16)
        out.append(contentsOf: "data".utf8); w32(dataSize)
        for s in buf {
            let v = Int16(max(-1, min(1, s)) * 32767)
            w16(UInt16(bitPattern: v))
        }
        return out
    }
}

// MARK: - BGM composition

private struct BgmNote { let t, d, f, g: Double; let w: Wave }

/// MIDI note -> Hz
private func m(_ n: Double) -> Double { 440 * pow(2, (n - 69) / 12) }

private func composeBGM(kind: BGM) -> Synth {
    let bpm: Double; let bars = 4; let beats: Double
    var seq: [BgmNote] = []
    func n(_ beat: Double, _ d: Double, _ f: Double, _ g: Double, _ w: Wave, _ bpm: Double) {
        let spb = 60.0 / bpm
        seq.append(BgmNote(t: beat * spb, d: d * spb, f: f, g: g, w: w))
    }
    switch kind {
    case .idle:
        bpm = 92; beats = Double(bars) * 4
        // gentle Am pentatonic arp + soft bass
        let bass: [Double] = [45, 45, 43, 41]            // A2 A2 G2 F2
        let arp:  [Double] = [57, 60, 64, 69, 72, 69, 64, 60]
        for b in 0..<bars {
            n(Double(b) * 4, 3.4, m(bass[b]), 0.30, .tri, bpm)
            n(Double(b) * 4, 0.5, m(bass[b] + 12), 0.06, .sine, bpm)
            for (i, a) in arp.enumerated() {
                n(Double(b) * 4 + Double(i) * 0.5, 0.4, m(a), 0.10, .sine, bpm)
            }
        }
    case .reach:
        bpm = 140; beats = Double(bars) * 4
        // driving minor riff Em: pumping 8th bass, offbeat stabs, 16th hats
        for b in 0..<bars {
            for e in 0..<8 {
                n(Double(b) * 4 + Double(e) * 0.5, 0.22, m(40), 0.34, .square, bpm)
                n(Double(b) * 4 + Double(e) * 0.5 + 0.25, 0.05, 6000, 0.10, .noise, bpm)
            }
            let stabs: [(Double, Double)] = [(1.0, 52), (1.5, 55), (3.0, 52), (3.5, 57)]
            for (bt, f) in stabs {
                n(Double(b) * 4 + bt, 0.18, m(f), 0.16, .saw, bpm)
                n(Double(b) * 4 + bt, 0.18, m(f + 3), 0.10, .saw, bpm)
            }
            n(Double(b) * 4 + 2, 0.12, 180, 0.5, .noise, bpm) // snare
        }
    case .rush:
        bpm = 168; beats = Double(bars) * 4
        // euphoric major lead + octave bass pump + hats
        let chords: [[Double]] = [[48, 52, 55], [45, 52, 57], [50, 53, 57], [47, 50, 55]] // C Am Dm G-ish
        let leadPat: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
        for b in 0..<bars {
            let ch = chords[b]
            for e in 0..<8 {
                n(Double(b) * 4 + Double(e) * 0.5, 0.24, m(ch[0] - 24 + (e % 2 == 0 ? 0 : 12)), 0.34, .saw, bpm)
                n(Double(b) * 4 + Double(e) * 0.5 + 0.25, 0.05, 7000, 0.09, .noise, bpm)
            }
            for (i, bt) in leadPat.enumerated() {
                n(Double(b) * 4 + bt, 0.4, m(ch[i % ch.count] + 24), 0.16, .square, bpm)
            }
            n(Double(b) * 4 + 2, 0.12, 200, 0.45, .noise, bpm)
        }
    }
    return renderBgm(seq: seq, bpm: bpm, beats: beats)
}

private func renderBgm(seq: [BgmNote], bpm: Double, beats: Double) -> Synth {
    let total = beats * 60 / bpm + 0.05
    let s = Synth(sampleRate: 44100, seconds: total)
    for n in seq where n.f > 0 {
        s.add(at: n.t, dur: n.d, wave: n.w, f0: n.f, gain: Float(n.g), attack: 0.004)
    }
    // limiter-ish soft normalize
    var peak: Float = 0.001
    for v in s.buf { peak = max(peak, abs(v)) }
    let k = 0.8 / peak
    for i in s.buf.indices { s.buf[i] *= k }
    return s
}

// MARK: - SoundEngine

enum BGM { case idle, reach, rush }

final class SoundEngine {
    static let shared = SoundEngine()

    private var sePlayers: [String: [AVAudioPlayer]] = [:]
    private var seIndex: [String: Int] = [:]
    private(set) var bgmPlayer: AVAudioPlayer?
    private var currentBGM: BGM?
    var muted = false { didSet { applyMute() } }

    private init() {}

    func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        if sePlayers.isEmpty { buildSE(); buildBGM() }
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fp_\(name).wav")
    }

    private func buildSE() {
        var defs: [String: (Synth) -> Void] = [:]
        defs["splash"] = { s in
            s.add(at: 0, dur: 0.28, wave: .noise, f0: 1200, f1: 300, gain: 0.5, attack: 0.002, lpf: true)
            s.add(at: 0, dur: 0.1, wave: .sine, f0: 300, f1: 90, gain: 0.4)
        }
        defs["bite"] = { s in s.add(at: 0, dur: 0.09, wave: .square, f0: 880, f1: 660, gain: 0.35) }
        defs["tick"] = { s in s.add(at: 0, dur: 0.04, wave: .square, f0: 1500, gain: 0.2) }
        defs["heart"] = { s in
            s.add(at: 0, dur: 0.10, wave: .sine, f0: 80, f1: 50, gain: 0.9)
            s.add(at: 0.14, dur: 0.09, wave: .sine, f0: 75, f1: 48, gain: 0.7)
        }
        defs["riser"] = { s in s.add(at: 0, dur: 1.1, wave: .saw, f0: 200, f1: 1600, gain: 0.25, attack: 0.05) }
        defs["siren"] = { s in
            for i in 0..<6 { s.add(at: Double(i) * 0.22, dur: 0.2, wave: .square, f0: i % 2 == 0 ? 620 : 930, gain: 0.22) }
        }
        defs["cutin"] = { s in
            s.add(at: 0, dur: 0.5, wave: .saw, f0: 110, f1: 110, gain: 0.4)
            s.add(at: 0, dur: 0.5, wave: .saw, f0: 165, f1: 165, gain: 0.3)
            s.add(at: 0, dur: 0.12, wave: .noise, f0: 3000, gain: 0.4, lpf: true)
            s.add(at: 0.12, dur: 0.4, wave: .saw, f0: 220, f1: 220, gain: 0.35)
        }
        defs["count"] = { s in s.add(at: 0, dur: 0.1, wave: .square, f0: 660, gain: 0.35) }
        defs["countgo"] = { s in s.add(at: 0, dur: 0.3, wave: .square, f0: 990, gain: 0.4) }
        defs["hook"] = { s in
            s.hit(at: 0, dur: 0.06, f: 5000, gain: 0.5)
            s.add(at: 0.02, dur: 0.35, wave: .saw, f0: 220, f1: 440, gain: 0.4)
        }
        defs["perfect"] = { s in
            let f: [Double] = [523, 659, 784, 1047]
            for (i, n) in f.enumerated() { s.add(at: Double(i) * 0.07, dur: 0.25, wave: .square, f0: n, gain: 0.3) }
        }
        defs["fanfare"] = { s in
            let notes: [(Double, Double)] = [(0, 523), (0.1, 659), (0.2, 784), (0.35, 1047), (0.35, 784), (0.55, 1319)]
            for (t, f) in notes { s.add(at: t, dur: 0.3, wave: .square, f0: f, gain: 0.28) }
            for (t, f) in notes { s.add(at: t, dur: 0.3, wave: .tri, f0: f / 2, gain: 0.22) }
        }
        defs["fanfare_big"] = { s in
            let chords: [(Double, [Double])] = [
                (0, [523, 659, 784]), (0.15, [587, 740, 880]), (0.3, [659, 784, 988]),
                (0.5, [784, 988, 1175]), (0.5, [523, 659, 784]), (0.75, [1047, 1319, 1568])
            ]
            for (t, ch) in chords { for f in ch { s.add(at: t, dur: 0.4, wave: .square, f0: f, gain: 0.2) } }
            s.add(at: 0.75, dur: 1.0, wave: .saw, f0: 262, gain: 0.25)
            s.add(at: 0.75, dur: 1.0, wave: .saw, f0: 392, gain: 0.2)
        }
        defs["coin"] = { s in
            s.add(at: 0, dur: 0.06, wave: .square, f0: 1980, gain: 0.25)
            s.add(at: 0.05, dur: 0.12, wave: .square, f0: 2640, gain: 0.2)
        }
        defs["escape"] = { s in
            s.add(at: 0, dur: 0.5, wave: .saw, f0: 440, f1: 110, gain: 0.3)
            s.add(at: 0.1, dur: 0.3, wave: .noise, f0: 800, f1: 200, gain: 0.2, lpf: true)
        }
        defs["surge"] = { s in
            s.add(at: 0, dur: 0.2, wave: .saw, f0: 150, f1: 320, gain: 0.4)
            s.hit(at: 0, dur: 0.08, f: 2500, gain: 0.3)
        }
        defs["break"] = { s in
            s.hit(at: 0, dur: 0.06, f: 6000, gain: 0.55)
            s.add(at: 0.03, dur: 0.6, wave: .saw, f0: 500, f1: 60, gain: 0.35)
        }
        defs["reel"] = { s in s.add(at: 0, dur: 0.05, wave: .square, f0: 2200, gain: 0.12) }
        defs["rush_in"] = { s in
            for i in 0..<8 { s.add(at: Double(i) * 0.06, dur: 0.2, wave: .square, f0: 523 + Double(i) * 120, gain: 0.22) }
            s.add(at: 0.5, dur: 0.8, wave: .saw, f0: 523, gain: 0.25)
            s.add(at: 0.5, dur: 0.8, wave: .saw, f0: 784, gain: 0.2)
        }
        defs["rush_out"] = { s in
            for (i, f) in [784.0, 659, 523, 392].enumerated() {
                s.add(at: Double(i) * 0.16, dur: 0.42, wave: .tri, f0: f, gain: 0.3)
            }
        }
        defs["charge"] = { s in s.add(at: 0, dur: 0.7, wave: .sine, f0: 220, f1: 880, gain: 0.25) }
        defs["cast"] = { s in s.add(at: 0, dur: 0.25, wave: .noise, f0: 2500, f1: 700, gain: 0.3, lpf: true) }
        defs["deny"] = { s in s.add(at: 0, dur: 0.15, wave: .square, f0: 220, f1: 180, gain: 0.3) }
        defs["thunder"] = { s in
            s.hit(at: 0, dur: 0.45, f: 900, gain: 0.65, decay: 0.3)
            s.add(at: 0.02, dur: 0.7, wave: .sine, f0: 95, f1: 38, gain: 0.7)
            s.hit(at: 0.06, dur: 0.3, f: 400, gain: 0.4, decay: 0.25)
        }
        defs["shine"] = { s in
            let f: [Double] = [1568, 1976, 2349, 2637, 3136]
            for (i, n) in f.enumerated() {
                s.add(at: Double(i) * 0.05, dur: 0.3, wave: .sine, f0: n, gain: 0.16)
            }
        }
        defs["impact"] = { s in
            s.hit(at: 0, dur: 0.1, f: 1800, gain: 0.55)
            s.add(at: 0, dur: 0.4, wave: .sine, f0: 120, f1: 42, gain: 0.8)
        }

        for (name, f) in defs {
            let s = Synth(sampleRate: 44100, seconds: 1.6)
            f(s)
            var peak: Float = 0.001
            for v in s.buf { peak = max(peak, abs(v)) }
            let k = 0.85 / peak
            for i in s.buf.indices { s.buf[i] *= k }
            save(s.wavData(), name)
            sePlayers[name] = makePlayers(name, count: name == "coin" || name == "reel" ? 6 : 3)
        }
    }

    private func buildBGM() {
        for kind in [BGM.idle, .reach, .rush] {
            let s = composeBGM(kind: kind)
            save(s.wavData(), "bgm_\(kind)")
        }
    }

    private func save(_ data: Data, _ name: String) {
        try? data.write(to: url(name))
    }

    private func makePlayers(_ name: String, count: Int) -> [AVAudioPlayer] {
        (0..<count).compactMap { _ in try? AVAudioPlayer(contentsOf: url(name)) }
    }

    func play(_ name: String) {
        guard !muted, let pool = sePlayers[name], !pool.isEmpty else { return }
        let i = (seIndex[name] ?? 0) % pool.count
        seIndex[name] = i + 1
        let p = pool[i]
        p.currentTime = 0
        p.play()
    }

    func bgm(_ kind: BGM) {
        guard currentBGM != kind else { return }
        currentBGM = kind
        let name = "bgm_\(kind)"
        guard let p = try? AVAudioPlayer(contentsOf: url(name)) else { return }
        p.numberOfLoops = -1
        p.volume = muted ? 0 : 0.5
        bgmPlayer?.setVolume(0, fadeDuration: 0.6)
        p.play()
        bgmPlayer = p
    }

    func stopBGM() {
        let player = bgmPlayer
        bgmPlayer = nil
        currentBGM = nil
        player?.setVolume(0, fadeDuration: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            player?.stop()
        }
    }

    private func applyMute() {
        bgmPlayer?.volume = muted ? 0 : 0.5
    }
}
