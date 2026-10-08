import SwiftUI

struct OldManCallout: View {
    let cue: OldManCue

    private var accent: Color { cue.heat == .warm ? .orange : Color(red: 0.23, green: 0.46, blue: 0.39) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(cue.heat.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 144)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("常連のおじさん")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                Text(cue.line)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.22))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1, green: 0.97, blue: 0.88), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.75), lineWidth: 2))
            .overlay(alignment: .leading) {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1, green: 0.97, blue: 0.88))
                    .offset(x: -8)
            }
            .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
        }
        .frame(maxWidth: 500)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .combine)
    }
}

struct OldManCutIn: View {
    let cue: OldManCue

    private var premium: Bool { cue.heat == .premium }
    private var accent: Color { premium ? .yellow : Color(red: 1, green: 0.35, blue: 0.2) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: premium
                        ? [Color(red: 0.13, green: 0.07, blue: 0.01), Color(red: 0.65, green: 0.36, blue: 0.02)]
                        : [Color(red: 0.16, green: 0.01, blue: 0.04), Color(red: 0.64, green: 0.05, blue: 0.03)],
                    startPoint: .bottomLeading, endPoint: .topTrailing)
                speedLines(in: geometry.size)
                HStack(alignment: .center, spacing: -10) {
                    Image(cue.heat.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.52, height: 310)
                        .shadow(color: accent.opacity(0.55), radius: 12)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(premium ? "伝説の気配" : "大物の予感")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accent, in: Capsule())
                        Text(cue.line)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black, radius: 2, x: 2, y: 2)
                            .shadow(color: accent.opacity(0.65), radius: 8)
                        Text("常連のおじさん")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(accent)
                    }
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack {
                    accent.frame(height: 3).shadow(color: accent, radius: 8)
                    Spacer()
                    accent.frame(height: 3).shadow(color: accent, radius: 8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
            .shadow(color: accent.opacity(0.5), radius: 14)
        }
        .frame(maxWidth: 540)
        .frame(height: 340)
        .dynamicTypeSize(.medium)
        .accessibilityElement(children: .combine)
    }

    private func speedLines(in size: CGSize) -> some View {
        Path { path in
            for index in 0..<14 {
                let y = CGFloat(index) * size.height / 13
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y - 110))
            }
        }
        .stroke(accent.opacity(0.2), lineWidth: 2)
    }
}
