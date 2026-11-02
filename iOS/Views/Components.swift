import SwiftUI

// MARK: - Glass surfaces

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var tint: Color? = nil
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? .regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// Slowly drifting aurora behind every screen. The glass layers above refract it.
struct AuroraBackground: View {
    var accent: Color = Theme.green
    var secondary: Color = Color(hex: 0x4F7BFF)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            let points: [SIMD2<Float>] = [
                SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
                SIMD2(0, 0.45 + 0.08 * sin(t * 0.30)),
                SIMD2(0.5 + 0.18 * sin(t * 0.21), 0.40 + 0.10 * cos(t * 0.17)),
                SIMD2(1, 0.50 + 0.08 * cos(t * 0.27)),
                SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1),
            ]
            let colors: [Color] = [
                accent.opacity(0.55), secondary.opacity(0.35), Theme.backgroundTop,
                Theme.backgroundTop, accent.opacity(0.18), secondary.opacity(0.25),
                Theme.backgroundBottom, Theme.backgroundBottom, Theme.backgroundBottom,
            ]
            MeshGradient(width: 3, height: 3, points: points, colors: colors)
        }
        .background(Theme.backgroundBottom)
        .ignoresSafeArea()
    }
}

// MARK: - Typography helpers

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(.secondary)
    }
}

struct BigNumber: View {
    var text: String
    var unit: String? = nil
    var size: CGFloat = 34

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            if let unit {
                Text(unit).font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            }
        }
        .monospacedDigit()
    }
}

struct SectionTitle: View {
    var title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title).font(.title2.weight(.semibold))
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}

// MARK: - Rows

enum Trend {
    case better, worse, neutral
    var color: Color {
        switch self {
        case .better: Theme.helps
        case .worse: Theme.hurts
        case .neutral: .secondary
        }
    }
}

/// "HEART RATE VARIABILITY ……… 124 ▲" row used on every detail screen.
struct ContributorRow: View {
    var symbol: String
    var title: String
    var value: String
    var arrowUp: Bool? = nil
    var trend: Trend = .neutral
    var bar: Double? = nil   // 0…1, optional quality bar

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 26)
                .foregroundStyle(.secondary)
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            if let bar {
                QualityBar(value: bar).frame(width: 70)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if let arrowUp {
                Image(systemName: arrowUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
                    .foregroundStyle(trend.color)
            } else {
                Circle().fill(.secondary).frame(width: 6, height: 6).padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 12)
    }
}

/// Three-segment poor / sufficient / optimal indicator.
struct QualityBar: View {
    var value: Double
    var body: some View {
        let level = value < 0.6 ? 0 : value < 0.85 ? 1 : 2
        let colors: [Color] = [Theme.hurts, .white.opacity(0.7), Theme.helps]
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == level ? colors[level] : .white.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }
}

struct InsightCallout: View {
    var text: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.callout).foregroundStyle(.white.opacity(0.9))
            if let action {
                Button {
                    onAction?()
                } label: {
                    Label(action.uppercased(), systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0x8FA8FF), Color(hex: 0xB28CFF)], startPoint: .leading, endPoint: .trailing))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color(hex: 0x6E7BFF).opacity(0.12)), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0x6E7BFF).opacity(0.7), Color(hex: 0x2FD4FF).opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) { configuration.title; configuration.icon }
    }
}

/// A big ring header shared by Recovery, Sleep and Strain detail screens.
struct HeroRing: View {
    var progress: Double
    var colors: [Color]
    var value: String
    var unit: String?
    var caption: String
    var marker: Double? = nil

    var body: some View {
        ScoreRing(progress: progress, colors: colors, lineWidth: 22, marker: marker) {
            VStack(spacing: 4) {
                Text("LUMEN").font(.caption.weight(.medium)).tracking(4).foregroundStyle(.secondary)
                BigNumber(text: value, unit: unit, size: 64)
                Text(caption.uppercased()).font(.footnote.weight(.semibold)).tracking(1.5)
            }
        }
        .frame(width: 260, height: 260)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Wraps detail screens in the standard background + scroll.
struct DetailScaffold<Content: View>: View {
    var title: String
    var accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 16) { content }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { AuroraBackground(accent: accent) }
        .navigationTitle(title.uppercased())
        .navigationBarTitleDisplayMode(.inline)
    }
}
