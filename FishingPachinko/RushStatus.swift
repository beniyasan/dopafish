import Foundation

enum RushRules {
    static let missThreshold = 0.18
    static let bonusThreshold = 0.66
    static let warningSpins = 3
    static let endingDuration = 2.4
    static let rodBiasPerLevel = 0.08
    static let reelBiasPerLevel = 0.10
    static let reelRescuePerLevel = 0.15

    static func boost(_ roll: Double, rareLevel: Int) -> Double {
        1 - (1 - roll) * (1 - rodBiasPerLevel * Double(rareLevel))
    }

    static func reelBoost(_ roll: Double, reelLevel: Int) -> Double {
        1 - (1 - roll) * (1 - reelBiasPerLevel * Double(reelLevel))
    }

    static func reelRescueProbability(reelLevel: Int) -> Double {
        reelRescuePerLevel * Double(reelLevel)
    }

    static func rarityCap(rareLevel: Int) -> Rarity {
        [.sr, .ssr, .ur, .lr, .lr, .lr][min(rareLevel, 5)]
    }

    static func gain(for rarity: Rarity, active: Bool, rushLevel: Int) -> Int {
        var spins = rarity == .lr ? 15 : rarity == .ur ? 10 : 0
        if active && rarity.rawValue >= Rarity.ssr.rawValue { spins += 2 }
        return spins > 0 ? spins + rushLevel : 0
    }

    /// 連打成功を条件とする1投の上乗せ抽選率。竿の上振れ・上限とリールの再抽選を含む。
    static func bonusProbability(rareLevel: Int, reelLevel: Int) -> Double {
        guard rarityCap(rareLevel: rareLevel).rawValue >= Rarity.ssr.rawValue else { return 0 }
        let rareScale = 1 - rodBiasPerLevel * Double(rareLevel)
        let direct = min(1, (1 - bonusThreshold) / rareScale)
        let miss = max(0, (missThreshold - (1 - rareScale)) / rareScale)
        let rescuedBonus = min(1, (1 - bonusThreshold)
            / ((1 - missThreshold) * (1 - reelBiasPerLevel * Double(reelLevel))))
        return min(1, direct + miss * reelRescueProbability(reelLevel: reelLevel) * rescuedBonus)
    }

    #if DEBUG
    static func debugStartingSpins(arguments: [String]) -> Int? {
        guard let i = arguments.firstIndex(of: "-rush"), i + 1 < arguments.count,
              let spins = Int(arguments[i + 1]), (1...99).contains(spins) else { return nil }
        return spins
    }
    #endif
}

struct RushStatus {
    let remaining: Int
    var isLast: Bool { remaining == 0 }
    var isUrgent: Bool { remaining <= RushRules.warningSpins }
    var heading: String { isLast ? "LAST CAST" : "RUSH" }
    var hint: String {
        if isLast { return "最終回転・この一投で上乗せを狙え" }
        return isUrgent ? "ラストスパート・SSR以上で上乗せ" : "高確率モード・スコア ×2"
    }
}

struct RushSummary {
    let id = UUID()
    let casts: Int
    let score: Int
}
