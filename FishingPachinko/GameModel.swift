import Foundation
import SwiftUI
import Combine

// MARK: - Types

enum Phase {
    case title, idle, charging, flying, waiting, reach, mash, reveal, escaping, rushEnding
}

enum Rarity: Int, CaseIterable { case n, r, sr, ssr, ur, lr
    var label: String { ["N", "R", "SR", "SSR", "UR", "LR"][rawValue] }
    var color: Color {
        [Color(white: 0.75), .cyan, .blue, .purple, .yellow, Color(red: 1, green: 0.4, blue: 0.8)][rawValue]
    }
    var next: Rarity { Rarity(rawValue: min(rawValue + 1, 5))! }
}

struct Banner {
    enum Style { case info, hot, gold, rainbow, miss, rush, small }
    let id = UUID()
    let text: String
    var sub: String = ""
    let style: Style
    var ttl: Double = 1.6
}

struct OldManCue: Identifiable {
    enum Heat: CaseIterable {
        case normal, warm, hot, premium

        var isCutIn: Bool { self == .hot || self == .premium }
        var imageName: String { isCutIn ? "OldManHot" : "OldManNormal" }
        var duration: Double { isCutIn ? 3.6 : 2.8 }
    }

    let id = UUID()
    let line: String
    let heat: Heat
}

struct Caught {
    let name: String
    let imageName: String
    let rarity: Rarity
    let cm: Int
    let score: Int
    let medals: Int
    let perfect: Bool
    let isRecord: Bool
    let rushGain: Int
    let isSmall: Bool   // N/R — the "it was just a small fish" ハズレ moment
    var isSecret = false // 幻魚フラグ（竿MAX限定・非公開）
}

/// Commands the game logic sends to the SpriteKit layer.
protocol GameFX: AnyObject {
    func resetScene()
    func castLure(power: Double)
    func lureLanded()
    func bobberDip(strength: Double)
    func setOrbit(speed: Double, radius: Double, visible: Bool)
    func shadowSize(_ s: Double)        // 0..1 fish silhouette size
    func zoomTo(_ level: Double)        // 1 = none, 2 = deep
    func shake(_ magnitude: Double)
    func splashFX(big: Bool)
    func sparkleBurst(color: UIColorCompat)
    func coinRain(_ n: Int)
    func hookLunge()
    func lineSnap()
    func setFightLook(struggling: Bool)
    func setRushLook(_ on: Bool)
    // 派手演出 (showtime fx — mode: 0 off / 1 white / 2 red / 3 gold / 4 rainbow)
    func setSpeedLines(_ mode: Int)     // 集中線 radiating toward center
    func setAura(_ mode: Int)           // 魚影オーラ burning silhouette
    func lightningFX()                  // 稲妻 sky-to-bobber bolt
    func lightPillar(color: UIColorCompat)  // 光の柱 beam column from the sea
    func shockwave(big: Bool)           // 衝撃波リング
    func confettiRain(_ n: Int)         // 紙吹雪
    func starShower(_ n: Int)           // 星のシャワー
    // 予告演出 (teasers — sometimes meaningful, often meaningless)
    func teaserFishJump()
    func teaserBirds(count: Int, golden: Bool)
    func teaserRainbow()
    func teaserRain(_ on: Bool)
    func teaserCloud(_ on: Bool)
    func teaserBoat()
    func teaserSchool()
    func teaserWaterGlow()
}

typealias UIColorCompat = UIColor

// MARK: - Fish pools

typealias FishSpec = (name: String, imageName: String, cm: ClosedRange<Int>, score: Int)

internal let fishPool: [Rarity: [FishSpec]] = [
    .n:   [("ワカサギ", "FishWakasagi", 6...14, 100), ("メダカ", "FishMedaka", 3...8, 80), ("ハゼ", "FishHaze", 8...15, 120)],
    .r:   [("アジ", "FishAji", 15...35, 250), ("メバル", "FishMebaru", 15...30, 300), ("サバ", "FishSaba", 25...45, 280)],
    .sr:  [("シーバス", "FishSeabass", 50...90, 700), ("マダイ", "FishMadai", 40...80, 900), ("ブリ", "FishBuri", 60...110, 800)],
    .ssr: [("ヒラマサ", "FishHiramasa", 100...180, 2200), ("カジキ", "FishKajiki", 200...350, 3000), ("キハダマグロ", "FishYellowfinTuna", 120...200, 2600)],
    .ur:  [("黄金龍魚", "FishGoldenDragonfish", 300...500, 6000), ("伝説の巨鯛", "FishLegendaryBream", 150...250, 5000)],
    .lr:  [("虹神クジラ", "FishRainbowWhale", 800...1200, 15000)],
]

// 幻魚 — RUSH中のみ超低確率で出現。図鑑には釣るまで載らない
internal let secretFishPool: [FishSpec] = [
    ("真夜中の星メダカ", "FishMidnightStarMedaka", 5...12, 4000),
    ("白銀の幻鮫", "FishSilverShark", 250...420, 8000),
    ("古代龍リュウグウノツカイ", "FishOarfish", 450...700, 11000),
]

// MARK: - 魚図鑑 (collection persistence)

final class DexStore: ObservableObject {
    static let shared = DexStore()
    /// name -> [caughtCount, maxCm]
    @Published private(set) var records: [String: [Int]] = [:]

    private init() {
        records = (UserDefaults.standard.dictionary(forKey: "fishDex") as? [String: [Int]]) ?? [:]
    }

    func log(_ name: String, cm: Int) {
        var e = records[name] ?? [0, 0]
        e[0] += 1
        e[1] = max(e[1], cm)
        records[name] = e
        UserDefaults.standard.set(records, forKey: "fishDex")
    }

    func entry(_ name: String) -> (count: Int, maxCm: Int) {
        let e = records[name] ?? [0, 0]
        return (e[0], e[1])
    }

    var caughtSpecies: Int { records.count }
    var totalSpecies: Int {
        fishPool.values.reduce(0) { $0 + $1.count }
    }
    var caughtSecrets: Int {
        secretFishPool.filter { (records[$0.name] ?? [0,0])[0] > 0 }.count
    }
}

// MARK: - GameModel

final class GameModel: ObservableObject {

    // Published UI state
    @Published var phase: Phase = .title
    @Published var score = 0
    @Published var medals = UserDefaults.standard.integer(forKey: "medals") {
        didSet { UserDefaults.standard.set(medals, forKey: "medals") }
    }
    @Published var combo = 0
    @Published var rushLeft = 0
    @Published var rushActive = false
    @Published private(set) var rushSummary: RushSummary?
    var rushStatus: RushStatus { RushStatus(remaining: rushLeft) }
    var rushBonusProbability: Double {
        RushRules.bonusProbability(rareLevel: rareLv, reelLevel: reelLv)
    }
    @Published var banner: Banner?
    @Published var prompt: String = ""
    @Published var promptHot = false
    @Published var flash: (color: Color, opacity: Double)? = nil
    @Published var reveal: Caught?
    @Published var chargePower: Double = 0
    @Published var tension: Double = 0      // battle theatre gauge (visual)
    @Published var mashCount = 0
    @Published var mashFill: Double = 0
    @Published var mashRemain: Double = 0
    /// 本物の魚が掛かっている時だけの残り必要連打数（ガセ中はnil）
    @Published private(set) var mashTapsLeft: Int?
    @Published private(set) var escapeReport: EscapeReport?
    @Published var autoCast = false
    var autoPower: Double = 0.65
    @Published var oldManCue: OldManCue?
    @Published var bestScore = UserDefaults.standard.integer(forKey: "bestScore")
    @Published var bestCm = UserDefaults.standard.integer(forKey: "bestCm")

    // 装備強化 (釣具屋) — コインで買う永久アップグレード、Lv0..5
    enum UpgradeTrack: Int, CaseIterable {
        case rare, reel, rush
        var title: String { ["金の竿", "強化リール", "RUSH券"][rawValue] }
        var icon: String { ["🎣", "⚙️", "🔥"][rawValue] }
        var effect: String {
            ["高レア魚が釣れる", "逃げ→再抽選で大物化", "RUSH突入+1回転/Lv"][rawValue]
        }
        var key: String { ["up_rare", "up_reel", "up_rush"][rawValue] }
    }
    static let upgradeCosts = [300, 600, 1100, 1700, 2500]   // Lv1〜5の価格
    @Published var rareLv = UserDefaults.standard.integer(forKey: "up_rare")
    @Published var reelLv = UserDefaults.standard.integer(forKey: "up_reel")
    @Published var rushLv = UserDefaults.standard.integer(forKey: "up_rush")

    func level(_ t: UpgradeTrack) -> Int {
        switch t { case .rare: return rareLv; case .reel: return reelLv; case .rush: return rushLv }
    }
    func nextCost(_ t: UpgradeTrack) -> Int? {
        let lv = level(t)
        return lv < Self.upgradeCosts.count ? Self.upgradeCosts[lv] : nil
    }
    @discardableResult
    func buyUpgrade(_ t: UpgradeTrack) -> Bool {
        guard let cost = nextCost(t), medals >= cost else { return false }
        medals -= cost
        let lv = level(t) + 1
        switch t {
        case .rare: rareLv = lv; UserDefaults.standard.set(lv, forKey: t.key)
        case .reel: reelLv = lv; UserDefaults.standard.set(lv, forKey: t.key)
        case .rush: rushLv = lv; UserDefaults.standard.set(lv, forKey: t.key)
        }
        snd.play("coin")
        return true
    }

    weak var fx: GameFX?

    // internals
    private var now: Double = 0
    private var pending: [(t: Double, act: () -> Void)] = []
    var result: Rarity? = nil               // nil = miss（テストから設定できるようinternal）
    @Published private(set) var reachKind = 0   // 0 normal 1 long 2 super 3 premium 4 rainbow
    private var biteTimer = 0.0
    private var landed = false
    private var battleT = 0.0
    private var spike = 0.0                 // tension spike during battle lunges
    private var mashT = 0.0
    private var mashDur = 3.0
    private var mashNeed = 12
    private var mashDone = false            // 連打フェーズが解決済みか（多重resolveCatch防止）
    private var rushCasts = 0
    private var rushStartScore = 0
    private var escapeShownAt = 0.0

    // debug: -rig ur / -rig miss etc, -fast for instant bites
    private let rig: String? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-rig"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }()
    private let fast = CommandLine.arguments.contains("-fast")
    private let autoStart = CommandLine.arguments.contains("-go")   // デバッグ: タイトル不要で即キャスト
    private let autoWin = CommandLine.arguments.contains("-win")   // デバッグ: 連打を自動化して当たり演出を確認する
    private let forceSecret = CommandLine.arguments.contains("-secret")   // デバッグ: 次の釣果を幻魚にする
    private var mashMult: Double = {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-mashneed"), i + 1 < a.count, let v = Double(a[i + 1]) { return v }
        return 1.0
    }()

    private let snd = SoundEngine.shared

    // MARK: clock / scheduler

    func tick(_ dt: Double) {
        // デバッグ -go: updateが回っている=シーン準備済みなのでここで開始する
        if autoStart && phase == .title { startGame() }
        now += dt
        while let first = pending.first, first.t <= now {
            pending.removeFirst()
            first.act()
        }
        switch phase {
        case .charging:
            chargePower = min(1, chargePower + dt / 0.9)
        case .reach:
            // theatrical line tension: base sine + decaying lunge spikes
            battleT += dt
            spike = max(0, spike - dt * 0.5)
            tension = min(1.1, 0.32 + 0.28 * sin(battleT * 3.2) + Double(reachKind) * 0.07 + spike)
        case .mash:
            mashT += dt
            mashRemain = max(0, mashDur - mashT)
            if autoWin { onMashTap() }
            if mashRemain <= 0 { resolveMash() }
        default: break
        }
    }

    private func schedule(_ after: Double, _ act: @escaping () -> Void) {
        pending.append((t: now + after, act: act))
        pending.sort { $0.t < $1.t }
    }

    private func showBanner(_ text: String, sub: String = "", style: Banner.Style, ttl: Double = 1.6) {
        let b = Banner(text: text, sub: sub, style: style, ttl: ttl)
        banner = b
        schedule(ttl) { [weak self] in
            if self?.banner?.id == b.id { self?.banner = nil }
        }
    }

    private func doFlash(_ color: Color, _ opacity: Double = 0.55, _ ttl: Double = 0.18) {
        flash = (color, opacity)
        schedule(ttl) { [weak self] in self?.flash = nil }
    }

    // MARK: game flow

    func startGame() {
        snd.prepare()
        #if DEBUG
        if let spins = RushRules.debugStartingSpins(arguments: CommandLine.arguments) {
            rushActive = true
            rushLeft = spins
            rushCasts = 0
            rushStartScore = score
        }
        #endif
        snd.bgm(rushActive ? .rush : .idle)
        phase = .idle
        prompt = "CASTボタン長押しでキャスト"
        fx?.resetScene()
        fx?.setRushLook(rushActive)
        scheduleAmbient()
        // デバッグ -go: tick経由で呼ばれた場合は即キャスト（シーン準備後なので安全）
        if autoStart {
            schedule(0.3) { [weak self] in self?.performCast(0.8) }
        }
    }

    func pressCast() {
        guard phase == .idle else { return }
        autoCast = false            // grabbing CAST by hand drops auto mode
        phase = .charging
        chargePower = 0
        snd.play("charge")
    }

    func releaseCast() {
        guard phase == .charging else { return }
        let power = 0.35 + 0.65 * chargePower
        autoPower = power           // remember strength for AUTO casts
        performCast(power)
    }

    private func performCast(_ power: Double) {
        phase = .flying
        prompt = ""
        chargePower = 0
        snd.play("cast")
        fx?.castLure(power: power)
        if rushActive && rushLeft > 0 {
            rushLeft -= 1
            rushCasts += 1
            if rushLeft <= RushRules.warningSpins {
                snd.play(rushLeft == 0 ? "countgo" : "count")
            }
        }
        schedule(0.45) { [weak self] in self?.land(power: power) }
    }

    func toggleAuto() {
        autoCast.toggle()
        if autoCast && phase == .idle {
            prompt = "AUTO: 強さ\(Int(autoPower * 100))%で連投中"
            schedule(0.5) { [weak self] in self?.autoFire() }
        }
        if !autoCast && phase == .idle {
            prompt = "CASTボタン長押しでキャスト"
        }
    }

    private func autoFire() {
        guard autoCast, phase == .idle else { return }
        performCast(autoPower)
    }

    private func land(power: Double) {
        landed = true
        snd.play("splash")
        fx?.lureLanded()
        fx?.splashFX(big: power > 0.85)
        phase = .waiting
        biteTimer = fast ? 0.3 : Double.random(in: 1.0...3.0) - power * 0.4
        rollResult()
        scheduleTeasers(delay: biteTimer)
        schedule(biteTimer) { [weak self] in self?.bite() }
        // fake-out nibble for tease sometimes
        if Double.random(in: 0...1) < 0.35 && biteTimer > 1.2 {
            schedule(biteTimer * 0.55) { [weak self] in
                guard self?.phase == .waiting else { return }
                self?.fx?.bobberDip(strength: 0.4)
                self?.snd.play("tick")
            }
        }
    }

    // MARK: bite & reach

    private func bite() {
        pickReach()
        fx?.bobberDip(strength: 1)
        snd.play("bite")
        Hap.impact(.medium)
        runReach()
    }

    private func rollResult() {
        if let rig {
            result = Rarity.allCases.first { "\($0)" == rig }
            return
        }
        var r = Double.random(in: 0...1)
        // 金の竿: 分布を上振り（Lv×8%レア寄り）
        r = RushRules.boost(r, rareLevel: rareLv)
        result = rarityForRoll(r)
        applyGearLimits()
    }

    /// 確率テーブル: r ∈ [0,1) → Rarity?（nil = 逃げ）。RUSH中は確率緩和
    func rarityForRoll(_ r: Double) -> Rarity? {
        if rushActive {
            switch r {
            case ..<RushRules.missThreshold: return nil
            case ..<0.36: return .n
            case ..<0.52: return .r
            case ..<RushRules.bonusThreshold: return .sr
            case ..<0.82: return .ssr
            case ..<0.95: return .ur
            default: return .lr
            }
        }
        switch r {
        case ..<0.42: return nil
        case ..<0.62: return .n
        case ..<0.76: return .r
        case ..<0.87: return .sr
        case ..<0.95: return .ssr
        case ..<0.985: return .ur
        default: return .lr
        }
    }

    /// 逃げ判定の閾値（再抽選はここより上を引く）
    private var missThreshold: Double { rushActive ? RushRules.missThreshold : 0.42 }

    private func applyGearLimits() {
        // 竿Lvが釣れるレアの上限 (Lv0:SR / 1:SSR / 2:UR / 3+:LR) — ゲーム内非表示仕様
        let cap = RushRules.rarityCap(rareLevel: rareLv)
        if let res = result, res.rawValue > cap.rawValue { result = cap }
        // 強化リール: 逃げを小型以上で再抽選 (Lv×15%)。Lvが高いほど大物寄り(Lv×10%上振り)
        if result == nil, Double.random(in: 0...1) < RushRules.reelRescueProbability(reelLevel: reelLv) {
            var r2 = Double.random(in: missThreshold...1.0)
            r2 = RushRules.reelBoost(r2, reelLevel: reelLv)
            let res = rarityForRoll(r2) ?? .n
            result = Rarity(rawValue: min(res.rawValue, cap.rawValue))
        }
    }

    private func pickReach() {
        if rig == "bluff" { reachKind = 2; return }   // デバッグ: ガセのスーパーリーチ
        let r = Double.random(in: 0...1)
        switch result {
        case .none: reachKind = r < 0.70 ? 0 : (r < 0.92 ? 1 : 2)          // 8% super-reach bluff!
        case .n:    reachKind = r < 0.8 ? 0 : 1
        case .r:    reachKind = r < 0.5 ? 0 : (r < 0.9 ? 1 : 2)
        case .sr:   reachKind = r < 0.55 ? 1 : (r < 0.95 ? 2 : 3)
        case .ssr:  reachKind = r < 0.7 ? 2 : 3
        case .ur:   reachKind = 3
        case .lr:   reachKind = 4
        }
    }

    // MARK: 予告 (teasers) — correlated with the hidden result, but with bluffs

    private static let oldManIdle: [String] = [
        "お、いい天気だな", "昔はもっと釣れたんだよ", "そろそろ帰るか…",
        "向こうの方が釣れそうだぞ", "餌は撒いておいたのかい?", "今日はここまでかな",
        "この釣り場は50年通ってるんだ", "お互いゆっくりやろうや"
    ]
    private static let oldManMild: [String] = [
        "いい引きをしてそうだ", "ウキの動きが良いぞ", "今日はツいてるな",
        "その場所、魚の通り道だよ"
    ]
    private static let oldManHot: [String] = [
        "…大物の気配がする", "静かすぎる…何か来るぞ", "俺のカンは当たるんだ",
        "おいおい、鳥が騒いでるぞ"
    ]
    private static let oldManPremium: [String] = [
        "……あれは、伝説のヤツだ", "50年で2度しか見てないぞ、あれを"
    ]

    private func scheduleTeasers(delay: Double) {
        guard delay > 0.6 else { return }
        // heat of the moment: does the hidden result warrant a hot teaser?
        let roll = Double.random(in: 0...1)
        var hot = false, mild = false
        switch result {
        case .none:    hot = roll < 0.05; mild = roll < 0.25   // ガセ予告!
        case .n, .r:   hot = roll < 0.10; mild = roll < 0.35
        case .sr:      hot = roll < 0.20; mild = roll < 0.60
        case .ssr:     hot = roll < 0.40; mild = roll < 0.80
        case .ur:      hot = roll < 0.60; mild = roll < 0.92
        case .lr:      hot = roll < 0.85; mild = true
        }

        // pure ambient — fires regardless ~55% of casts
        if Double.random(in: 0...1) < 0.55 {
            let ambient: [() -> Void] = [
                { [weak self] in self?.fx?.teaserFishJump() },
                { [weak self] in self?.fx?.teaserBirds(count: Int.random(in: 3...5), golden: false) },
                { [weak self] in self?.fx?.teaserBoat() },
                { [weak self] in self?.fx?.teaserCloud(true); self?.schedule(4) { self?.fx?.teaserCloud(false) } },
                { [weak self] in self?.fx?.teaserSchool() },
            ]
            let pick = ambient.randomElement()!
            schedule(delay * Double.random(in: 0.25...0.6)) { pick() }
        }

        if mild {
            let mildEvents: [() -> Void] = [
                { [weak self] in self?.fx?.teaserBirds(count: Int.random(in: 7...10), golden: false) },
                { [weak self] in self?.fx?.teaserWaterGlow() },
                { [weak self] in self?.showOldMan(Self.oldManMild.randomElement()!, heat: .warm) },
            ]
            let pick = mildEvents.randomElement()!
            schedule(delay * Double.random(in: 0.4...0.7)) { pick() }
        }

        if hot {
            let r = Double.random(in: 0...1)
            schedule(delay * Double.random(in: 0.55...0.8)) { [weak self] in
                guard let self else { return }
                if result == .lr && r < 0.5 {
                    self.showOldMan(Self.oldManPremium.randomElement()!, heat: .premium)
                } else if r < 0.4 {
                    self.fx?.teaserRainbow()
                } else if r < 0.7 {
                    self.fx?.teaserBirds(count: 1, golden: true)
                } else if r < 0.85 {
                    // rain → rainbow chain
                    self.fx?.teaserRain(true)
                    self.schedule(2.2) { self.fx?.teaserRain(false) }
                    self.schedule(2.6) { self.fx?.teaserRainbow() }
                } else {
                    self.showOldMan(Self.oldManHot.randomElement()!, heat: .hot)
                }
            }
        }
    }

    func showOldMan(_ line: String, heat: OldManCue.Heat = .normal) {
        guard phase == .idle || phase == .waiting || phase == .reach else { return }
        if oldManCue?.heat.isCutIn == true && !heat.isCutIn { return }
        let cue = OldManCue(line: line, heat: heat)
        oldManCue = cue
        if heat.isCutIn {
            snd.play("cutin")
            Hap.impact(.heavy)
            fx?.shake(heat == .premium ? 5 : 3)
        }
        schedule(heat.duration) { [weak self] in
            if self?.oldManCue?.id == cue.id { self?.oldManCue = nil }
        }
    }

    private var ambientArmed = false
    /// Ambient life while idle (meaningless by nature — that's the point)
    private func scheduleAmbient() {
        guard !ambientArmed else { return }
        ambientArmed = true
        schedule(Double.random(in: 4...9)) { [weak self] in
            guard let self else { return }
            self.ambientArmed = false
            guard self.phase == .idle else { return }
            switch Int.random(in: 0...5) {
            case 0: self.fx?.teaserFishJump()
            case 1: self.fx?.teaserBirds(count: Int.random(in: 3...6), golden: false)
            case 2: self.fx?.teaserBoat()
            case 3: self.showOldMan(Self.oldManIdle.randomElement()!)
            case 4:
                self.fx?.teaserCloud(true)
                self.schedule(4.5) { self.fx?.teaserCloud(false) }
            default: self.fx?.teaserSchool()
            }
            self.scheduleAmbient()
        }
    }

    private func runReach() {
        phase = .reach
        battleT = 0
        spike = 0
        let k = reachKind
        // 影の大きさはリーチの熱さに連動（結果ではない — 大きな影がハズレるのがガセ）
        fx?.shadowSize([0.3, 0.45, 0.7, 0.9, 1.1][k])
        fx?.setFightLook(struggling: true)
        fx?.setOrbit(speed: [1.8, 2.5, 4.2, 4.0, 5.2][k],
                     radius: [42, 55, 70, 80, 90][k], visible: true)

        // 影のオーラと集中線もリーチ熱さに連動（結果ではない — ガセも燃える）
        fx?.setAura(k)
        fx?.setSpeedLines(k >= 2 ? k : 0)

        let dur: Double = [2.4, 4.2, 6.2, 8.2, 9.6][k]
        let lunges = [1, 2, 4, 6, 7][k]
        for i in 0..<lunges {
            schedule(0.6 + dur * Double(i) / Double(lunges)) { [weak self] in
                self?.battleLunge(strong: k >= 2)
            }
        }

        switch k {
        case 0:
            showBanner("食いついた!", style: .info, ttl: 1.2)
        case 1:
            showBanner("引いてる…!", style: .info, ttl: 1.4)
            schedule(1.6) { [weak self] in self?.showBanner("粘ってるぞ…", style: .info, ttl: 1.2) }
        case 2:
            enterSuperLook()
            schedule(0.1) { [weak self] in self?.showBanner("大物の影だ!!", sub: "スーパーバトルリーチ", style: .hot, ttl: 1.8) }
            for i in 0..<7 {
                schedule(0.5 + Double(i) * 0.7) { [weak self] in self?.snd.play("heart"); Hap.impact(.heavy) }
            }
            schedule(3.4) { [weak self] in self?.showBanner("まだ逃げてない…!!", style: .hot, ttl: 1.4) }
            schedule(4.9) { [weak self] in self?.showBanner("手前まで来た!!", style: .hot, ttl: 1.2) }
        case 3:
            enterPremiumLook(rainbow: false)
            schedule(0.1) { [weak self] in self?.showBanner("ゴールデンバトル!!", sub: "確変大物の激闘…!", style: .gold, ttl: 2.2) }
            for i in 0..<8 {
                schedule(0.5 + Double(i) * 0.65) { [weak self] in self?.snd.play("heart"); Hap.impact(.heavy) }
            }
            schedule(3.0) { [weak self] in self?.showBanner("折れそうだ…!!", style: .gold, ttl: 1.4) }
            for i in 0..<3 {
                schedule(5.4 + Double(i) * 0.7) { [weak self] in
                    self?.prompt = "\(3 - i)"; self?.promptHot = true
                    self?.snd.play("count"); Hap.impact(.heavy); self?.fx?.shake(6)
                }
            }
            schedule(7.6) { [weak self] in self?.prompt = "GO!!"; self?.snd.play("countgo") }
        default: // rainbow
            enterPremiumLook(rainbow: true)
            schedule(0.1) { [weak self] in self?.showBanner("!?!?", sub: "この引きは…何だ!?", style: .rainbow, ttl: 1.8) }
            schedule(2.0) { [weak self] in self?.showBanner("虹色バトル!!!", sub: "伝説確定!?", style: .rainbow, ttl: 2.4) }
            for i in 0..<8 {
                schedule(0.6 + Double(i) * 0.75) { [weak self] in
                    self?.fx?.sparkleBurst(color: .white); self?.snd.play("heart"); Hap.impact(.heavy)
                }
            }
            schedule(6.4) { [weak self] in self?.showBanner("伝説が暴れてる!!!", style: .rainbow, ttl: 1.6) }
            for i in 0..<3 {
                schedule(7.0 + Double(i) * 0.7) { [weak self] in
                    self?.prompt = "\(3 - i)"; self?.promptHot = true
                    self?.snd.play("count"); Hap.impact(.heavy); self?.fx?.shake(7)
                }
            }
            schedule(9.1) { [weak self] in self?.prompt = "GO!!"; self?.snd.play("countgo") }
        }
        schedule(dur) { [weak self] in self?.endReach() }
    }

    private func battleLunge(strong: Bool) {
        spike = min(0.45, spike + (strong ? 0.34 : 0.22))
        fx?.bobberDip(strength: strong ? 1.4 : 0.9)
        fx?.splashFX(big: strong)
        fx?.shake(strong ? 7 : 3)
        if strong { fx?.shockwave(big: false) }
        snd.play(strong ? "surge" : "bite")
        Hap.impact(strong ? .heavy : .medium)
    }

    private func endReach() {
        guard phase == .reach else { return }
        // タダ〜ロングリーチのハズレはそのまま逃げる（短い＝外れ、パチンコと同じ構造）
        if result == nil && reachKind <= 1 {
            escape("逃げられた…")
        } else {
            beginMash()
        }
    }

    private func enterSuperLook() {
        snd.bgm(.reach)
        snd.play("siren")
        snd.play("cutin")
        snd.play("thunder")
        fx?.setOrbit(speed: 4.5, radius: 70, visible: true)
        fx?.zoomTo(1.5)
        fx?.shake(4)
        fx?.lightningFX()
        doFlash(.red, 0.35, 0.25)
    }

    private func enterPremiumLook(rainbow: Bool) {
        snd.bgm(.reach)
        snd.play("cutin")
        snd.play("riser")
        snd.play("thunder")
        fx?.setOrbit(speed: rainbow ? 5.5 : 4.0, radius: 78, visible: true)
        fx?.zoomTo(rainbow ? 2.0 : 1.75)
        doFlash(rainbow ? .purple : .yellow, 0.5, 0.35)
        fx?.shake(8)
        fx?.lightningFX()
        for i in 0..<3 {
            schedule(0.8 + Double(i) * 0.9) { [weak self] in
                self?.fx?.sparkleBurst(color: rainbow ? .systemPink : .systemYellow)
            }
        }
        if rainbow {
            for i in 0..<3 {
                schedule(2.4 + Double(i) * 1.9) { [weak self] in
                    self?.fx?.lightningFX()
                    self?.snd.play("thunder")
                    self?.fx?.shake(5)
                }
            }
        }
    }

    // MARK: 連打 (the mashing finale — 押せ!!)

    private func beginMash() {
        guard phase == .reach else { return }
        oldManCue = nil
        phase = .mash
        mashT = 0
        mashCount = 0
        mashFill = 0
        mashDone = false
        mashDur = 2.4 + 0.32 * Double(reachKind) + 0.4 * Double(reelLv)
        mashNeed = Int(Double(result.map { [8, 10, 14, 18, 22, 28][$0.rawValue] } ?? 999) * mashMult)
        mashTapsLeft = result == nil ? nil : mashNeed
        prompt = "連打!!"
        promptHot = true
        snd.play("cutin")
        fx?.zoomTo(1.3)
        fx?.setSpeedLines(max(3, reachKind))   // クライマックスは金色以上の集中線
        fx?.setOrbit(speed: 3.0, radius: 30, visible: true)
        showBanner("連打!!", sub: "画面を連打で引き上げろ!", style: .hot, ttl: 1.3)
    }

    func tapScreen() {
        switch phase {
        case .mash:
            onMashTap()
        case .reach:
            // taps during battle do nothing but feel alive — pachinko レバオン気分
            snd.play("tick")
            fx?.splashFX(big: false)
        case .reveal:
            dismissReveal()
        case .title:
            startGame()
        case .rushEnding:
            dismissRushSummary()
        case .escaping:
            dismissEscape()
        default: break
        }
    }

    private func onMashTap() {
        guard !mashDone else { return }
        mashCount += 1
        snd.play("reel")
        Hap.impact(.light)
        fx?.bobberDip(strength: 0.5)
        fx?.shockwave(big: false)
        if mashCount % 6 == 0 { fx?.shake(4); fx?.splashFX(big: true) }
        let raw = Double(mashCount) / Double(max(1, mashNeed))
        // ハズレ結果は連打してもメーターが85%で止まる — クライマックスでバレる
        mashFill = result == nil ? min(raw, 0.85 + 0.04 * sin(mashT * 9)) : min(1, raw)
        if result != nil { mashTapsLeft = max(0, mashNeed - mashCount) }
        if let r = result, mashCount >= mashNeed {
            // overfill = 激連打 bonus
            let perfect = mashCount >= Int(Double(mashNeed) * 1.25)
            _ = r
            resolveCatch(perfect: perfect)
        }
    }

    private func resolveMash() {
        if let r = result, mashCount >= mashNeed {
            _ = r
            resolveCatch(perfect: false)
        } else if let r = result {
            // 連打不足 — 実際に掛かっていた魚を見せる（図鑑・スコアには記録しない）
            let fish = fishPool[r]!.randomElement()!
            let kind = EscapeReport.Kind.lineBreak(
                rarity: r, fishName: fish.name, imageName: fish.imageName,
                cm: Int.random(in: fish.cm), discovered: DexStore.shared.entry(fish.name).count > 0)
            escape(report: EscapeReport(kind: kind, mashCount: mashCount, mashNeed: mashNeed))
        } else {
            // ガセ — 大きな影だけで魚はいなかった
            escape(report: EscapeReport(kind: .bluff, mashCount: mashCount, mashNeed: mashNeed))
        }
    }

    private func resolveCatch(perfect: Bool) {
        guard phase == .mash, !mashDone else { return }
        mashDone = true
        prompt = ""
        snd.play("hook")
        snd.play("impact")
        Hap.impact(.heavy)
        fx?.hookLunge()
        fx?.splashFX(big: true)
        fx?.shockwave(big: true)
        if perfect {
            showBanner("激連打 PERFECT!!", style: .gold, ttl: 1.0)
            snd.play("perfect")
        }
        let r = result ?? .n
        // 大物(SR+)なら大当たり演出、小物(N/R)はがっかりカード（ハズレ相当）
        schedule(0.55) { [weak self] in self?.caught(perfect: perfect, small: r.rawValue <= Rarity.r.rawValue) }
    }

    // MARK: resolve

    private func caught(perfect: Bool, small: Bool) {
        oldManCue = nil
        let r = result ?? .n
        var pick = fishPool[r]!.randomElement()!
        var isSecret = false
        // 幻魚: 竿MAX(Lv5)でのみ ~4% 出現（非公開仕様）。-secret で強制確認可
        if forceSecret || (level(.rare) >= Self.upgradeCosts.count && Double.random(in: 0...1) < 0.04) {
            pick = secretFishPool.randomElement()!
            isSecret = true
        }
        let cm = Int.random(in: pick.cm)
        DexStore.shared.log(pick.name, cm: cm)
        var sc = pick.score
        if perfect { sc = Int(Double(sc) * 1.5) }
        if rushActive { sc *= 2 }
        sc = Int(Double(sc) * (1 + min(0.5, Double(combo) * 0.08)))
        let isRecord = cm > bestCm
        if isRecord { bestCm = cm; UserDefaults.standard.set(cm, forKey: "bestCm") }
        score += sc
        if score > bestScore { bestScore = score; UserDefaults.standard.set(score, forKey: "bestScore") }
        let medal = max(1, sc / 12)
        medals += medal
        combo += 1

        let rushGain = RushRules.gain(for: r, active: rushActive, rushLevel: rushLv)

        reveal = Caught(name: pick.name, imageName: pick.imageName, rarity: r, cm: cm,
                        score: sc, medals: medal, perfect: perfect, isRecord: isRecord,
                        rushGain: rushGain, isSmall: small, isSecret: isSecret)
        phase = .reveal
        prompt = ""
        fx?.setFightLook(struggling: false)
        fx?.setOrbit(speed: 0, radius: 0, visible: false)
        fx?.zoomTo(1)
        fx?.setSpeedLines(0)
        fx?.setAura(0)

        // jackpot presentation
        if r.rawValue >= Rarity.ur.rawValue {
            doFlash(.yellow, 0.7, 0.3)
            snd.play("fanfare_big")
            snd.play("thunder")
            snd.play("shine")
            Hap.notify(.success)
            showBanner(r == .lr ? "超弩級当たり!!!!" : "大当たり!!!", sub: "+\(sc)pt", style: r == .lr ? .rainbow : .gold, ttl: 2.4)
            fx?.coinRain(min(60, medal))
            fx?.lightPillar(color: r == .lr
                            ? UIColorCompat(red: 1, green: 0.5, blue: 0.9, alpha: 1)
                            : UIColorCompat(red: 1, green: 0.9, blue: 0.3, alpha: 1))
            fx?.lightningFX()
            fx?.confettiRain(48)
            fx?.starShower(40)
        } else if r.rawValue >= Rarity.sr.rawValue {
            doFlash(.white, 0.5, 0.2)
            snd.play("fanfare")
            snd.play("shine")
            Hap.notify(.success)
            showBanner("当たり!", sub: "+\(sc)pt", style: .hot, ttl: 1.8)
            fx?.coinRain(min(30, medal))
            fx?.lightPillar(color: UIColorCompat(red: 0.6, green: 0.9, blue: 1, alpha: 1))
            fx?.starShower(18)
        } else {
            // 小物 — ハズレ相当の拍子抜け演出
            snd.play("deny")
            snd.play("coin")
            Hap.notify(.warning)
            showBanner("…小物だった", sub: "+\(sc)pt", style: .miss, ttl: 1.6)
            fx?.coinRain(min(12, medal))
        }
        schedule(0.5) { [weak self] in self?.fx?.splashFX(big: true) }
    }

    func dismissReveal() {
        guard phase == .reveal, let caught = reveal else { return }
        let rushGain = caught.rushGain
        reveal = nil
        if rushGain > 0 {
            let wasActive = rushActive
            if !wasActive {
                rushCasts = 0
                rushStartScore = score
            }
            rushActive = true
            rushLeft += rushGain
            fx?.setRushLook(true)
            snd.bgm(.rush)
            snd.play("rush_in")
            snd.play("shine")
            fx?.lightPillar(color: UIColorCompat(red: 1, green: 0.85, blue: 0.3, alpha: 1))
            fx?.starShower(24)
            fx?.setSpeedLines(3)
            schedule(1.9) { [weak self] in self?.fx?.setSpeedLines(0) }
            showBanner(wasActive ? "RUSH継続!!" : "RUSH突入!!!",
                       sub: "高確率 \(rushLeft)回転", style: .rush, ttl: 2.2)
            schedule(2.2) { [weak self] in self?.toIdle() }
        } else {
            toIdle()
        }
    }

    private func escape(_ reason: String = "", report: EscapeReport? = nil) {
        oldManCue = nil
        phase = .escaping
        prompt = ""
        mashTapsLeft = nil
        tension = 0
        combo = 0
        snd.play("escape")
        snd.play("break")
        Hap.notify(.error)
        fx?.setFightLook(struggling: false)
        fx?.setOrbit(speed: 0, radius: 0, visible: false)
        fx?.zoomTo(1)
        fx?.setSpeedLines(0)
        fx?.setAura(0)
        fx?.lineSnap()
        doFlash(.black, 0.35, 0.3)
        guard let report else {
            showBanner(reason, style: .miss, ttl: 1.2)
            schedule(1.3) { [weak self] in self?.toIdle() }
            return
        }
        banner = nil
        escapeReport = report
        escapeShownAt = now
        if report.isNearMiss || report.isBigFish {
            fx?.shake(report.isNearMiss ? 6 : 4)
        }
        schedule(EscapeReport.displayDuration) { [weak self] in
            guard self?.escapeReport?.id == report.id else { return }
            self?.dismissEscape(force: true)
        }
    }

    /// 逃げ演出を閉じる。連打の勢いで即スキップされないよう、表示直後のタップは無視する
    func dismissEscape(force: Bool = false) {
        guard phase == .escaping, escapeReport != nil else { return }
        guard force || now - escapeShownAt >= EscapeReport.skipLockDuration else { return }
        escapeReport = nil
        toIdle()
    }

    private func toIdle() {
        if rushActive && rushLeft <= 0 {
            endRush()
            return
        }
        phase = .idle
        landed = false
        prompt = autoCast ? "AUTO: 強さ\(Int(autoPower * 100))%で連投中" : "CASTボタン長押しでキャスト"
        promptHot = false
        fx?.resetScene()
        fx?.zoomTo(1)
        scheduleAmbient()
        if autoCast { schedule(1.0) { [weak self] in self?.autoFire() } }
        if !rushActive {
            snd.bgm(.idle)
        }
    }

    private func endRush() {
        phase = .rushEnding
        rushActive = false
        rushLeft = 0
        let summary = RushSummary(casts: rushCasts, score: score - rushStartScore)
        rushSummary = summary
        prompt = ""
        promptHot = false
        banner = nil
        oldManCue = nil
        landed = false
        fx?.resetScene()
        fx?.setRushLook(false)
        fx?.zoomTo(1)
        snd.stopBGM()
        snd.play("rush_out")
        schedule(RushRules.endingDuration) { [weak self] in
            guard self?.rushSummary?.id == summary.id else { return }
            self?.dismissRushSummary()
        }
    }

    func dismissRushSummary() {
        guard phase == .rushEnding else { return }
        rushSummary = nil
        toIdle()
    }

}
