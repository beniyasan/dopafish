import Foundation

/// 連打で逃げた直後に見せる「惜しかった」情報。表示内容はすべて実際の抽選・連打結果から作る。
struct EscapeReport: Identifiable {
    enum Kind: Equatable {
        /// 本当に魚が掛かっていたが連打が足りなかった
        case lineBreak(rarity: Rarity, fishName: String, imageName: String, cm: Int, discovered: Bool)
        /// 魚のいないガセ（大きな影だけ）
        case bluff
    }

    static let displayDuration = 2.2
    static let skipLockDuration = 0.6
    static let nearMissTaps = 3

    let id = UUID()
    let kind: Kind
    let tapsShort: Int
    let progress: Double

    init(kind: Kind, mashCount: Int, mashNeed: Int) {
        self.kind = kind
        if case .lineBreak = kind {
            tapsShort = max(1, mashNeed - mashCount)
            progress = min(1, Double(mashCount) / Double(max(1, mashNeed)))
        } else {
            tapsShort = 0
            progress = 0
        }
    }

    var isNearMiss: Bool {
        if case .lineBreak = kind { return tapsShort <= Self.nearMissTaps }
        return false
    }

    var isBigFish: Bool {
        if case .lineBreak(let rarity, _, _, _, _) = kind { return rarity.rawValue >= Rarity.sr.rawValue }
        return false
    }

    var headline: String {
        switch kind {
        case .bluff: return "影だけだった…"
        case .lineBreak: return isNearMiss ? "あと\(tapsShort)回だった!!" : "バラした…"
        }
    }

    var subline: String {
        switch kind {
        case .bluff: return "魚の姿はなかった"
        case .lineBreak: return isNearMiss ? "惜しい!! 逃げられた…" : "あと\(tapsShort)回足りなかった"
        }
    }

    /// 図鑑未登録の魚は名前を伏せる
    var displayName: String {
        switch kind {
        case .bluff: return "？？？"
        case .lineBreak(_, let name, _, _, let discovered): return discovered ? name : "？？？"
        }
    }

    var isUndiscovered: Bool {
        if case .lineBreak(_, _, _, _, let discovered) = kind { return !discovered }
        return false
    }
}
