import SwiftUI

// MARK: - 魚図鑑

struct DexOverlay: View {
    let onClose: () -> Void
    @ObservedObject private var dex = DexStore.shared

    private let sections: [(Rarity, String)] = [
        (.n, "N — 小物"), (.r, "R — 並"), (.sr, "SR — 大物"),
        (.ssr, "SSR — 超大物"), (.ur, "UR — 激レア"), (.lr, "LR — 伝説"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 0) {
                // header
                VStack(spacing: 6) {
                    HStack {
                        Text("📖 魚図鑑")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    HStack {
                        Text("捕獲 \(dex.caughtSpecies) / \(dex.totalSpecies) 種")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Spacer()
                        if dex.caughtSpecies >= dex.totalSpecies {
                            Text("🏆 コンプリート!!")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.15))
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .yellow],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * CGFloat(dex.caughtSpecies) / CGFloat(max(1, dex.totalSpecies)))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(sections, id: \.0) { (rarity, title) in
                            dexSection(rarity, title)
                        }
                        secretSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: 340, maxHeight: 600)
            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 2))
        }
    }

    private func dexSection(_ rarity: Rarity, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(rarity.color)
            ForEach(fishPool[rarity] ?? [], id: \.name) { fish in
                dexRow(name: fish.name, emoji: fish.emoji, rarity: rarity, secret: false)
            }
        }
    }

    private var secretSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("??? — 幻")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
            if dex.caughtSecrets == 0 {
                Text("まだ見ぬ魚がいるという噂がある…")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.vertical, 4)
            } else {
                ForEach(secretFishPool, id: \.name) { fish in
                    if dex.entry(fish.name).count > 0 {
                        dexRow(name: fish.name, emoji: fish.emoji, rarity: .lr, secret: true)
                    }
                }
            }
        }
    }

    private func dexRow(name: String, emoji: String, rarity: Rarity, secret: Bool) -> some View {
        let e = dex.entry(name)
        let caught = e.count > 0
        return HStack(spacing: 10) {
            Text(caught ? emoji : "❔")
                .font(.system(size: 26))
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(caught ? name : "？？？")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(caught ? .white : .white.opacity(0.35))
                    if secret {
                        Text("幻")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.purple, in: Capsule())
                    }
                }
                Text(caught ? "最大 \(e.maxCm)cm" : "未捕獲")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(caught ? .cyan : .white.opacity(0.3))
            }
            Spacer()
            if caught {
                Text("×\(e.count)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(caught ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(caught ? rarity.color.opacity(0.45) : .clear, lineWidth: 1))
    }
}

// MARK: - 釣具屋 (shop)

struct ShopOverlay: View {
    @ObservedObject var model: GameModel
    let onClose: () -> Void
    @State private var flashBuy: GameModel.UpgradeTrack?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 14) {
                HStack {
                    Text("🛒 釣具屋")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                HStack {
                    Text("🪙 \(model.medals)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                    Spacer()
                }
                ForEach(GameModel.UpgradeTrack.allCases, id: \.rawValue) { t in
                    shopRow(t)
                }
                Text("強化はずっと続く。釣って稼いで強くしよう")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 2))
        }
    }

    private func shopRow(_ t: GameModel.UpgradeTrack) -> some View {
        let lv = model.level(t)
        let cost = model.nextCost(t)
        let canBuy = cost != nil && model.medals >= (cost ?? 0)
        return HStack(spacing: 12) {
            Text(t.icon).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(t.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    levelPips(lv)
                }
                Text(t.effect)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button {
                if model.buyUpgrade(t) {
                    flashBuy = t
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if flashBuy == t { flashBuy = nil }
                    }
                }
            } label: {
                if let cost {
                    Text("🪙\(cost)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(canBuy ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(canBuy ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                } else {
                    Text("MAX")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.orange.opacity(0.2), in: Capsule())
                }
            }
            .disabled(!canBuy)
        }
        .padding(12)
        .background(flashBuy == t ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    private func levelPips(_ lv: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<GameModel.upgradeCosts.count, id: \.self) { i in
                Circle()
                    .fill(i < lv ? Color.yellow : Color.white.opacity(0.18))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
