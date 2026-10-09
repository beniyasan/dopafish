import SwiftUI

/// 逃げた魚のチラ見せカード。画面のどこをタップしても閉じる（表示直後はモデル側で無視）
struct EscapeCard: View {
    let report: EscapeReport
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text(report.headline)
                        .font(.system(size: report.isNearMiss ? 38 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(headlineStyle)
                        .shadow(color: report.isNearMiss ? .red.opacity(0.8) : .black, radius: 10)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(report.subline)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    silhouette
                    details
                    Text("タップで次へ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(20)
                .frame(width: min(geometry.size.width - 32, 340))
                .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(borderColor, lineWidth: 2))
                .scaleEffect(appear || reduceMotion ? 1 : 1.25)
                .offset(x: appear || reduceMotion ? 0 : (report.isNearMiss ? 18 : 0))
                .opacity(appear ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15)
                          : .spring(response: 0.3, dampingFraction: 0.45)) { appear = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var silhouette: some View {
        switch report.kind {
        case .lineBreak(_, let name, let imageName, _, let discovered):
            FishArtwork(imageName: imageName, name: discovered ? name : report.displayName)
                .saturation(0)
                .brightness(discovered ? -0.55 : -0.85)
                .blur(radius: discovered ? 0 : 3)
                .frame(maxHeight: 150)
                .overlay {
                    if !discovered {
                        Text("？")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
        case .bluff:
            Image(systemName: "fish.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .foregroundStyle(.white.opacity(0.12))
                .blur(radius: 2)
                .frame(maxWidth: .infinity, minHeight: 110)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder private var details: some View {
        switch report.kind {
        case .lineBreak(let rarity, _, _, let cm, let discovered):
            HStack(spacing: 8) {
                Text("\(rarity.label)級")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(rarity.color, in: Capsule())
                Text(report.displayName)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("推定\(cm)cm")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if !discovered {
                Text("図鑑未登録の魚だった…")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.yellow)
            }
            VStack(spacing: 4) {
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: [.yellow, .orange, .red],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: bar.size.width * report.progress)
                    }
                }
                .frame(height: 12)
                Text("連打 \(Int(report.progress * 100))%・あと\(report.tapsShort)回")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .bluff:
            Text("大物の影は消えた…")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var headlineStyle: AnyShapeStyle {
        report.isNearMiss
            ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(Color.gray)
    }

    private var borderColor: Color {
        switch report.kind {
        case .lineBreak(let rarity, _, _, _, _): return report.isNearMiss ? .red : rarity.color.opacity(0.7)
        case .bluff: return .gray.opacity(0.5)
        }
    }
}
