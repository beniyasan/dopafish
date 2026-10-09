import SwiftUI

struct RushHUD: View {
    let status: RushStatus
    let bonusProbability: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var accent: Color { status.isUrgent ? .red : .orange }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(status.heading)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(status.isUrgent ? .white : .yellow)
                if status.isLast {
                    Text("最終回転")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(.yellow)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("残り")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(status.remaining)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("回転")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(status.hint)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(status.isUrgent ? .yellow : .white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "上乗せ抽選 %.1f%% / 投", bonusProbability * 100))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("当選後の連打成功が必要")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 330)
        .background(
            LinearGradient(colors: [accent.opacity(0.9), .black.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(status.isUrgent ? Color.yellow : .orange, lineWidth: 2)
                .opacity(status.isUrgent && !reduceMotion && pulse ? 0.45 : 1)
        }
        .shadow(color: accent.opacity(status.isUrgent && !reduceMotion && pulse ? 0.8 : 0.3),
                radius: 10)
        .padding(.horizontal, 12)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                   value: status.remaining)
        .onAppear { updatePulse() }
        .onChange(of: status.isUrgent) { _, _ in updatePulse() }
        .onChange(of: reduceMotion) { _, _ in updatePulse() }
        .allowsHitTesting(false)
    }

    private func updatePulse() {
        pulse = false
        if status.isUrgent && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct RushEndView: View {
    let summary: RushSummary
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("RUSH FINISH")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, .yellow, .orange],
                                                     startPoint: .top, endPoint: .bottom))
                    .shadow(color: .orange.opacity(0.5), radius: 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("RUSH終了")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 24) {
                    result("\(summary.casts)", label: "消化回転")
                    result("+\(summary.score)", label: "RUSH獲得pt")
                }
                Button("通常モードへ", action: onContinue)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(.yellow, in: Capsule())
                Text("まもなく通常モードへ戻ります")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(24)
            .frame(maxWidth: 350)
            .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.orange, lineWidth: 2))
            .padding(.horizontal, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
    }

    private func result(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.yellow)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
