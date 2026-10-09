import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var model = GameModel()
    @State private var scene: GameScene = GameScene()
    @State private var muted = false
    @State private var hotPulse = false
    @State private var showDex = false
    @State private var showShop = false

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // flash overlay
            if let f = model.flash {
                f.color.opacity(f.opacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // reach vignette
            if model.phase == .reach || model.phase == .mash {
                RadialGradient(colors: [.clear, .black.opacity(0.55)],
                               center: .center, startRadius: 120, endRadius: 420)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // hot reach: pulsing danger vignette (super and up — heat reads at a glance)
            if (model.phase == .reach && model.reachKind >= 2) || model.phase == .mash {
                RadialGradient(colors: [.clear, Color.red.opacity(0.42)],
                               center: .center, startRadius: 140, endRadius: 430)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(hotPulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                               value: hotPulse)
                    .onAppear { hotPulse = true }
                    .onDisappear { hotPulse = false }
            }

            VStack {
                hud
                Spacer()
                promptArea
            }

            if model.phase == .idle || model.phase == .charging {
                castControls
            }
            if model.phase == .reach {
                battleGauge
            }
            if model.phase == .mash {
                mashMeter
            }

            if let cue = model.oldManCue, !cue.heat.isCutIn {
                VStack {
                    Spacer()
                    OldManCallout(cue: cue)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 210)
                }
                .id(cue.id)
                .allowsHitTesting(false)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if let b = model.banner {
                BannerView(banner: b)
                    .id(b.id)
                    .allowsHitTesting(false)
            }

            if let cue = model.oldManCue, cue.heat.isCutIn {
                OldManCutIn(cue: cue)
                    .padding(.horizontal, 10)
                    .offset(y: -25)
                    .id(cue.id)
                    .allowsHitTesting(false)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .opacity))
            }

            if let r = model.reveal {
                RevealCard(caught: r)
                    .onTapGesture { model.dismissReveal() }
            }

            if let report = model.escapeReport {
                EscapeCard(report: report, onTap: { model.dismissEscape() })
                    .id(report.id)
            }

            if let summary = model.rushSummary {
                RushEndView(summary: summary, onContinue: model.dismissRushSummary)
            }

            if showDex {
                DexOverlay(onClose: { showDex = false })
            }
            if showShop {
                ShopOverlay(model: model, onClose: { showShop = false })
            }

            if model.phase == .title {
                titleScreen
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        muted.toggle()
                        SoundEngine.shared.muted = muted
                    } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                }
                Spacer()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.oldManCue?.id)
        .onAppear {
            scene.logic = model
            model.fx = scene
        }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(model.score)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                    Text("🪙 \(model.medals)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                .padding(.leading, 14)
                .padding(.top, 8)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if model.combo > 1 {
                        Text("COMBO ×\(model.combo)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    Text("BEST \(model.bestScore)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    if model.bestCm > 0 {
                        Text("最大 \(model.bestCm)cm")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.trailing, 54) // leave room for mute
                .padding(.top, 8)
            }
            if model.autoCast {
                Text("⚡ AUTO 強さ\(Int(model.autoPower * 100))%")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Color.yellow, in: Capsule())
            }
            if model.rushActive {
                RushHUD(status: model.rushStatus, bonusProbability: model.rushBonusProbability)
            }
        }
    }

    // MARK: prompts & controls

    private var promptArea: some View {
        VStack(spacing: 14) {
            Text(model.prompt)
                .font(.system(size: model.promptHot ? 30 : 17,
                              weight: .black, design: .rounded))
                .foregroundStyle(model.promptHot ? Color.yellow : .white)
                .shadow(color: .black.opacity(0.6), radius: 3)
                .opacity(model.prompt.isEmpty ? 0 : 1)
                .scaleEffect(model.promptHot ? 1 + 0.08 * sin(CACurrentMediaTime() * 12) : 1)
                .padding(.bottom, 120)
        }
    }

    private var castControls: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 130, height: 130)
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 3))
                Circle()
                    .trim(from: 0, to: model.chargePower)
                    .stroke(AngularGradient(colors: [.cyan, .yellow, .red],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text("🎣").font(.system(size: 34))
                    Text("CAST")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .trailing) {
                if model.phase == .idle {
                    VStack(spacing: 10) {
                        autoButton
                        shopButton
                    }
                    .offset(x: 92)
                }
            }
            .overlay(alignment: .leading) {
                if model.phase == .idle {
                    dexButton.offset(x: -92)
                }
            }
            .padding(.bottom, 52)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if model.phase == .idle { model.pressCast() } }
                    .onEnded { _ in if model.phase == .charging { model.releaseCast() } }
            )
        }
    }

    private var dexButton: some View {
        Button { showDex = true } label: {
            VStack(spacing: 2) {
                Text("図鑑")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text("\(DexStore.shared.caughtSpecies)/\(DexStore.shared.totalSpecies)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.black.opacity(0.35), in: Capsule())
        }
    }

    private var shopButton: some View {
        Button { showShop = true } label: {
            VStack(spacing: 2) {
                Text("釣具")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text("強化")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.black.opacity(0.35), in: Capsule())
        }
    }

    private var autoButton: some View {
        Button(action: model.toggleAuto) {
            VStack(spacing: 2) {
                Text(model.autoCast ? "AUTO" : "AUTO")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(model.autoCast ? "強さ\(Int(model.autoPower * 100))%" : "OFF")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(model.autoCast ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(model.autoCast ? Color.yellow : Color.white.opacity(0.15),
                        in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(model.autoCast ? 0 : 0.4), lineWidth: 1.5))
        }
    }

    /// 糸テンション — battle theatre gauge shown while the shadow fights (visual only)
    private var battleGauge: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Text("糸")
                    .font(.caption).fontWeight(.black).foregroundStyle(.white)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule()
                            .fill(model.tension > 0.85 ? Color.red : model.tension > 0.6 ? .orange : .green)
                            .frame(width: g.size.width * min(1, model.tension))
                            .shadow(color: model.tension > 0.85 ? .red : .clear, radius: 6)
                    }
                }
                .frame(height: 14)
            }
            .frame(width: 250)
            .padding(.bottom, 170)
        }
        .allowsHitTesting(false)
    }

    /// 押せ!! the mashing finale — fill the bar by tapping anywhere
    private var mashMeter: some View {
        VStack(spacing: 14) {
            Spacer()
            let left = model.mashTapsLeft ?? 0
            Text("あと\(left)回!!")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.yellow, .red],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .red, radius: 10)
                .contentTransition(.numericText())
                .opacity((1...5).contains(left) ? 1 : 0)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2)).frame(height: 34)
                Capsule()
                    .fill(LinearGradient(colors: [.yellow, .orange, .red],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, model.mashFill)) * 300)
                    .shadow(color: .yellow.opacity(0.9), radius: 10)
            }
            .frame(width: 300, height: 34)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(model.mashCount)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .orange, radius: 12)
                    .contentTransition(.numericText())
                Text("連打!")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(String(format: "%.1f", model.mashRemain))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.bottom, 130)
        .allowsHitTesting(false)
    }

    // MARK: title

    private var titleScreen: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("DOPAGAKI")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .orange, radius: 18)
                Text("Fishing Collection")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("大当たりでRUSH突入!\n音量・脳汁注意")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                Text("TAP TO START")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.top, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.startGame() }
    }
}

// MARK: - Banner

struct BannerView: View {
    let banner: Banner
    @State private var appear = false

    var body: some View {
        VStack(spacing: 4) {
            Text(banner.text)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(fill)
                .shadow(color: shadowColor, radius: 14)
                .scaleEffect(appear ? 1 : 2.2)
                .opacity(appear ? 1 : 0)
            if !banner.sub.isEmpty {
                Text(banner.sub)
                    .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 4)
                    .scaleEffect(appear ? 1 : 1.8)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { appear = true }
        }
    }

    private var size: CGFloat {
        switch banner.style {
        case .small: return 26
        case .miss, .info: return 34
        case .hot: return 52
        case .gold, .rush: return 56
        case .rainbow: return 58
        }
    }

    private var shadowColor: Color {
        switch banner.style {
        case .gold, .rush: return .yellow
        case .rainbow: return .purple
        case .hot: return .red
        default: return .black.opacity(0.6)
        }
    }

    private var fill: AnyShapeStyle {
        switch banner.style {
        case .miss:
            return AnyShapeStyle(Color.gray)
        case .info, .small:
            return AnyShapeStyle(Color.white)
        case .hot:
            return AnyShapeStyle(LinearGradient(colors: [.yellow, .red],
                                                startPoint: .top, endPoint: .bottom))
        case .gold, .rush:
            return AnyShapeStyle(LinearGradient(colors: [.white, .yellow, .orange],
                                                startPoint: .top, endPoint: .bottom))
        case .rainbow:
            return AnyShapeStyle(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                                startPoint: .leading, endPoint: .trailing))
        }
    }
}

// MARK: - Reveal card

struct RevealCard: View {
    let caught: Caught
    @State private var pop = false
    private var spec: CardFXSpec { .forCatch(caught) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(spec.dimOpacity).ignoresSafeArea()
                CardFXBackdrop(spec: spec)
                ScrollView {
                    RevealCardContent(caught: caught, spec: spec, artworkVisible: pop)
                        .padding(22)
                        .frame(width: min(geometry.size.width - 32, 360))
                        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
                        .overlay(CardBorder(spec: spec))
                        .overlay(ShineSweep(spec: spec))
                        .scaleEffect(pop ? 1 : spec.entryScale)
                        .rotationEffect(.degrees(pop ? 0 : spec.entrySpin))
                        .opacity(pop ? 1 : 0)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.top)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.38,
                                  dampingFraction: spec.tier >= 3 ? 0.48 : 0.6)
                .delay(spec.entryDelay)) { pop = true }
        }
    }
}

struct RevealCardContent: View {
    let caught: Caught
    var spec: CardFXSpec
    var artworkVisible = true
    @State private var labelPulse = false

    init(caught: Caught, spec: CardFXSpec? = nil, artworkVisible: Bool = true) {
        self.caught = caught
        self.spec = spec ?? .forCatch(caught)
        self.artworkVisible = artworkVisible
    }

    var body: some View {
        VStack(spacing: 10) {
            rarityLabel
            if caught.isSecret {
                Text("✦ シークレット!! ✦")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink, .cyan],
                                       startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .purple, radius: 10)
            }
            FishArtwork(imageName: caught.imageName, name: caught.name)
                .scaleEffect(artworkVisible ? 1 : 0.2)
                .rotationEffect(.degrees(artworkVisible ? 0 : -30))
            if caught.isSmall {
                Text("…実は小物だった")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.gray)
            }
            Text(caught.name)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("\(caught.cm) cm")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.cyan)
            if caught.isRecord {
                Text("✨ NEW RECORD! ✨")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            }
            if caught.perfect {
                Text("PERFECT BONUS ×1.5")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }
            Text("+\(caught.score) pt   🪙+\(caught.medals)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
            if caught.rushGain > 0 {
                Text("RUSH +\(caught.rushGain) 回転!!")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.vertical, 5)
                    .background(.yellow, in: Capsule())
            }
            Text("タップで続く")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 4)
        }
    }

    /// レア度ラベル — SSR+ で脈動、LR で虹色回転
    @ViewBuilder private var rarityLabel: some View {
        if spec.hueCycle {
            TimelineView(.animation) { tl in
                rarityBase
                    .hueRotation(.degrees(tl.date.timeIntervalSinceReferenceDate * 90))
            }
        } else {
            rarityBase
        }
    }

    private var rarityBase: some View {
        Text(caught.rarity.label)
            .font(.system(size: 40, weight: .black, design: .rounded))
            .foregroundStyle(labelFill)
            .shadow(color: spec.accent, radius: 16)
            .scaleEffect(spec.labelPulse && labelPulse ? 1.12 : 1)
            .animation(
                spec.labelPulse
                    ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                    : .default,
                value: labelPulse)
            .onAppear { labelPulse = true }
    }

    private var labelFill: AnyShapeStyle {
        if spec.hueCycle {
            return AnyShapeStyle(LinearGradient(
                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(spec.accent)
    }
}
