import SwiftUI

// MARK: - 釣果カード演出 (per-rarity card showtime)
// CardFXSpec decides how loud a reveal card gets. Tier 0 (N/R) stays a
// subdued anticlimax; each step up adds light, motion, and shine.
// Spec is pure data so tests can pin the rarity -> effect mapping.

struct CardFXSpec {
    enum BorderStyle: Int, Comparable {
        case plain, glow, shimmer, rainbow
        static func < (lhs: BorderStyle, rhs: BorderStyle) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let tier: Int            // 0 = N/R, 1 = SR, 2 = SSR, 3 = UR, 4 = LR (secrets floor at 2)
    let accent: Color        // rarity color
    let dimOpacity: Double   // backdrop darkness behind the card
    let rayCount: Int        // rotating god-ray blades (0 = off)
    let raySpeed: Double     // degrees/sec
    let rayRainbow: Bool     // rays cycle through hues
    let sparkleCount: Int    // floating sparkles behind the card
    let ringCount: Int       // expanding shockwave rings on entry
    let entryFlash: Bool     // radial flash burst on entry
    let entryShine: Bool     // one shine sweep right after the pop
    let shinePeriod: Double  // seconds between shine sweeps (0 = entry sweep only)
    let border: BorderStyle
    let entryDelay: Double   // beat of anticipation before the card pops
    let entryScale: Double   // card scale before the pop
    let entrySpin: Double    // degrees of spin-in
    let labelPulse: Bool     // rarity label breathes
    let hueCycle: Bool       // LR master switch — everything hue-cycles

    static func forCatch(_ c: Caught) -> CardFXSpec {
        let base = max(0, c.rarity.rawValue - 1)
        let tier = c.isSecret ? max(2, base) : base   // 幻魚は最低でもSSR級の派手さ
        switch tier {
        case 0:
            return CardFXSpec(tier: 0, accent: c.rarity.color, dimOpacity: 0.50,
                              rayCount: 0, raySpeed: 0, rayRainbow: false,
                              sparkleCount: 0, ringCount: 0, entryFlash: false,
                              entryShine: false, shinePeriod: 0, border: .plain,
                              entryDelay: 0, entryScale: 0.40, entrySpin: -8,
                              labelPulse: false, hueCycle: false)
        case 1:
            return CardFXSpec(tier: 1, accent: c.rarity.color, dimOpacity: 0.55,
                              rayCount: 0, raySpeed: 0, rayRainbow: false,
                              sparkleCount: 12, ringCount: 0, entryFlash: true,
                              entryShine: true, shinePeriod: 0, border: .glow,
                              entryDelay: 0, entryScale: 0.38, entrySpin: -10,
                              labelPulse: false, hueCycle: false)
        case 2:
            return CardFXSpec(tier: 2, accent: c.rarity.color, dimOpacity: 0.60,
                              rayCount: 10, raySpeed: 16, rayRainbow: false,
                              sparkleCount: 20, ringCount: 0, entryFlash: true,
                              entryShine: true, shinePeriod: 2.8, border: .glow,
                              entryDelay: 0.05, entryScale: 0.34, entrySpin: -14,
                              labelPulse: true, hueCycle: false)
        case 3:
            return CardFXSpec(tier: 3, accent: c.rarity.color, dimOpacity: 0.64,
                              rayCount: 14, raySpeed: 26, rayRainbow: false,
                              sparkleCount: 32, ringCount: 1, entryFlash: true,
                              entryShine: true, shinePeriod: 1.8, border: .shimmer,
                              entryDelay: 0.12, entryScale: 0.26, entrySpin: -20,
                              labelPulse: true, hueCycle: false)
        default:
            return CardFXSpec(tier: 4, accent: c.rarity.color, dimOpacity: 0.68,
                              rayCount: 18, raySpeed: 34, rayRainbow: true,
                              sparkleCount: 46, ringCount: 2, entryFlash: true,
                              entryShine: true, shinePeriod: 1.2, border: .rainbow,
                              entryDelay: 0.22, entryScale: 0.18, entrySpin: -26,
                              labelPulse: true, hueCycle: true)
        }
    }
}

// MARK: - backdrop (全画面 — カードの後ろに敷く層)

struct CardFXBackdrop: View {
    let spec: CardFXSpec

    var body: some View {
        ZStack {
            if spec.tier > 0 {
                CardGlow(spec: spec)
            }
            if spec.rayCount > 0 {
                CardRays(spec: spec)
            }
            if spec.sparkleCount > 0 {
                CardSparkles(spec: spec)
            }
            if spec.entryFlash {
                EntryFlash(spec: spec)
            }
            ForEach(0..<spec.ringCount, id: \.self) { i in
                EntryRing(spec: spec, delay: 0.14 * Double(i))
            }
        }
        .allowsHitTesting(false)
    }
}

/// カード背後の脈動グロー — the card radiates its rarity color
private struct CardGlow: View {
    let spec: CardFXSpec
    @State private var pulse = false
    @State private var spin = false

    var body: some View {
        RadialGradient(colors: [spec.accent.opacity(0.5), spec.accent.opacity(0.12), .clear],
                       center: .center, startRadius: 20, endRadius: 340)
            .scaleEffect(pulse ? 1.12 : 0.92)
            .opacity(pulse ? 0.9 : 0.55)
            .hueRotation(.degrees(spin ? 360 : 0))
            .onAppear {
                pulse = true
                if spec.hueCycle {
                    withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                        spin = true
                    }
                }
            }
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
    }
}

/// 回転する光条 — conic-gradient blades sweeping behind the card (SSR+)
private struct CardRays: View {
    let spec: CardFXSpec

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let rot = spec.raySpeed * t
            Circle()
                .fill(AngularGradient(gradient: Gradient(stops: stops(t: t)),
                                      center: .center,
                                      startAngle: .degrees(rot),
                                      endAngle: .degrees(rot + 360)))
                .mask(RadialGradient(colors: [.white, .white.opacity(0.7), .clear],
                                     center: .center, startRadius: 30, endRadius: 330))
                .blendMode(.screen)
        }
        .opacity(0.55)
        .ignoresSafeArea()
    }

    private func stops(t: Double) -> [Gradient.Stop] {
        var s: [Gradient.Stop] = []
        let n = Double(spec.rayCount)
        for i in 0..<spec.rayCount {
            let f = Double(i) / n
            let col = spec.rayRainbow
                ? Color(hue: (f + t * 0.05).truncatingRemainder(dividingBy: 1),
                        saturation: 0.85, brightness: 1)
                : spec.accent
            s.append(.init(color: col.opacity(0.9), location: f))
            s.append(.init(color: col.opacity(0), location: min(1, f + 0.5 / n)))
        }
        return s
    }
}

/// 浮遊スパークル — deterministic rising sparks (SR+), seeded per index
private struct CardSparkles: View {
    let spec: CardFXSpec

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { (ctx: inout GraphicsContext, size: CGSize) in
                let w = Double(size.width), h = Double(size.height)
                for i in 0..<spec.sparkleCount {
                    var rng = LCG(seed: UInt64(i) &* 2654435761 &+ 97)
                    let x0 = rng.next() * w
                    let rise = 24 + rng.next() * 44
                    let sway = 5 + rng.next() * 12
                    let ph = rng.next() * 60
                    let s0 = 1.4 + rng.next() * 2.6
                    let span = h + 60
                    let y = h + 20 - (t * rise + ph * 20).truncatingRemainder(dividingBy: span)
                    let x = x0 + sin(t * (0.7 + rng.next()) + ph) * sway
                    let tw = 0.35 + 0.65 * abs(sin(t * (1.6 + rng.next() * 2) + ph * 3))
                    let col = spec.hueCycle
                        ? Color(hue: (ph / 60 + t * 0.06).truncatingRemainder(dividingBy: 1),
                                saturation: 0.8, brightness: 1)
                        : spec.accent
                    ctx.opacity = tw
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s0, height: s0)),
                             with: .color(col))
                }
            }
        }
        .blendMode(.screen)
        .ignoresSafeArea()
    }
}

/// 登場フラッシュ — radial burst that sells the pop (SR+)
private struct EntryFlash: View {
    let spec: CardFXSpec
    @State private var go = false

    var body: some View {
        let cols: [Color] = spec.hueCycle
            ? [.white, Color(hue: 0.85, saturation: 0.6, brightness: 1).opacity(0.7), .clear]
            : [.white, spec.accent.opacity(0.85), .clear]
        // 固定frameの拡大はレイアウトサイズを膨らませてZStack兄弟のカードを押し出すので、
        // 小さい土台+overlayで視覚だけ拡大する（overlay内の子はクリップされない）
        Color.clear
            .frame(width: 80, height: 80)
            .overlay(
                RadialGradient(colors: cols, center: .center, startRadius: 0, endRadius: 60)
                    .frame(width: go ? 1100 : 80, height: go ? 1100 : 80)
                    .opacity(go ? 0 : 0.95)
                    .blendMode(.screen))
            .onAppear {
                withAnimation(.easeOut(duration: spec.hueCycle ? 0.7 : 0.5)
                    .delay(spec.entryDelay * 0.5)) { go = true }
            }
    }
}

/// 拡大リング — shockwave rings behind the card on entry (UR+)
private struct EntryRing: View {
    let spec: CardFXSpec
    let delay: Double
    @State private var go = false

    var body: some View {
        // EntryFlashと同じく、拡大frameは土台+overlayでレイアウトから切り離す
        Color.clear
            .frame(width: 80, height: 80)
            .overlay(
                Circle()
                    .stroke(ringStroke, lineWidth: go ? 2 : 10)
                    .frame(width: go ? 860 : 80, height: go ? 860 : 80)
                    .opacity(go ? 0 : 0.85))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(spec.entryDelay + delay)) { go = true }
            }
    }

    private var ringStroke: AnyShapeStyle {
        if spec.hueCycle {
            return AnyShapeStyle(AngularGradient(
                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                center: .center))
        }
        return AnyShapeStyle(spec.accent)
    }
}

// MARK: - カード枠 (the border itself)

struct CardBorder: View {
    let spec: CardFXSpec
    @State private var glowUp = false

    var body: some View {
        switch spec.border {
        case .plain:
            RoundedRectangle(cornerRadius: 24)
                .stroke(spec.accent, lineWidth: 3)
                .shadow(color: spec.accent, radius: 10)
        case .glow:
            RoundedRectangle(cornerRadius: 24)
                .stroke(spec.accent.opacity(0.95), lineWidth: 3.5)
                .shadow(color: spec.accent, radius: glowUp ? 24 : 9)
                .shadow(color: spec.accent.opacity(0.6), radius: glowUp ? 5 : 2)
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                           value: glowUp)
                .onAppear { glowUp = true }
        case .shimmer, .rainbow:
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderGradient(t: t), lineWidth: 4)
                    .shadow(color: spec.accent.opacity(0.9), radius: 16 + 9 * sin(t * 4.5))
            }
        }
    }

    private func borderGradient(t: Double) -> AngularGradient {
        if spec.border == .rainbow {
            return AngularGradient(
                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                center: .center,
                startAngle: .degrees(t * 40), endAngle: .degrees(t * 40 + 360))
        }
        return AngularGradient(
            colors: [spec.accent, .white, spec.accent, .white.opacity(0.65), spec.accent],
            center: .center,
            startAngle: .degrees(t * 55), endAngle: .degrees(t * 55 + 360))
    }
}

// MARK: - キラ掃射 (shine band sweeping the card face — keeps art readable)

struct ShineSweep: View {
    let spec: CardFXSpec
    private let sweepDur = 0.8
    @State private var t0 = Date.timeIntervalSinceReferenceDate

    var body: some View {
        if spec.entryShine || spec.shinePeriod > 0 {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate - t0
                GeometryReader { g in
                    if let pos = sweepX(elapsed: t, width: g.size.width) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, .white.opacity(0.7), .clear],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(60, g.size.width * 0.28),
                                   height: g.size.height * 1.6)
                            .rotationEffect(.degrees(16))
                            .position(x: pos, y: g.size.height / 2)
                            .blendMode(.screen)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    /// First sweep fires just after the pop; later sweeps every shinePeriod.
    private func sweepX(elapsed: Double, width: Double) -> CGFloat? {
        let first = 0.45 + spec.entryDelay
        guard elapsed >= first else { return nil }
        let local = spec.shinePeriod > 0
            ? (elapsed - first).truncatingRemainder(dividingBy: spec.shinePeriod)
            : elapsed - first
        guard local <= sweepDur else { return nil }
        let frac = local / sweepDur
        return CGFloat(-0.35 + 1.7 * frac) * width
    }
}

// MARK: - deterministic PRNG for sparkles

private struct LCG {
    var s: UInt64
    init(seed: UInt64) { s = seed }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double((s >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}
