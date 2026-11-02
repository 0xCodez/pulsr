import SwiftUI

/// Colour sets for the orb. Recovery picks green / yellow / red by zone.
enum OrbPalette: Equatable {
    case recovery(Double?)
    case spectral
    case sleep
    case strain

    var hex: [UInt32] {
        switch self {
        case .recovery(let value):
            switch value.map(RecoveryZone.init) {
            case .yellow: return [0xFFD84D, 0xFF8A3D, 0xFF5FA2, 0x7B6CFF]
            case .red: return [0xFF4D6A, 0xFF8A3D, 0xB44BFF, 0xFF2D9B]
            default: return [0x2FD4FF, 0x2EF2A0, 0x7B6CFF, 0xFFB25B]
            }
        case .spectral: return [0x3D7BFF, 0xFF4FD8, 0x2FE6FF, 0xFF8A1F]
        case .sleep: return [0x8C7BFF, 0x5AD8FF, 0xC08BFF, 0x3D5BFF]
        case .strain: return [0x2FD4FF, 0x3D6BFF, 0x00F0FF, 0x9C7BFF]
        }
    }

    /// In light mode the colours are deepened so they read on a pale screen.
    func colors(light: Bool) -> [Color] {
        hex.map { light ? Color(hex: $0).mix(with: .black, by: 0.22, in: .device) : Color(hex: $0) }
    }
}

/// Heart-like double pulse ("lub-dub") at ~52 bpm.
enum OrbBeat {
    static let period = 60.0 / 52.0

    static func value(at t: TimeInterval) -> Double {
        let ph = t.truncatingRemainder(dividingBy: period)
        func g(_ x: Double, _ c: Double, _ w: Double) -> Double { exp(-pow((x - c) / w, 2)) }
        return min(1, g(ph, 0, 0.07) + g(ph, period, 0.07) + 0.55 * g(ph, 0.3, 0.08))
    }
}

/// The recovery orb: ribbons of light inside a glowing volume, with no edge or shadow.
/// The view's frame is the sphere's diameter; the glow spreads beyond it and is never clipped.
struct HaloOrb: View {
    var palette: OrbPalette
    var energy: Double = 0.5   // widens the glow
    var speed: Double = 1
    var forceDark = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 2.2 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                let beat = reduceMotion ? 0 : OrbBeat.value(at: t)
                let light = !forceDark && scheme == .light
                OrbLayer(time: t * speed, beat: beat, light: light, spread: 0.6 * (0.85 + 0.3 * energy),
                         colors: palette.colors(light: light), diameter: d)
                    .frame(width: d * 1.8, height: d * 1.8)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if os(iOS)
/// GPU path: the Metal shader in iOS/Shaders/Orb.metal.
private struct OrbLayer: View {
    var time: Double, beat: Double, light: Bool, spread: Double
    var colors: [Color]
    var diameter: CGFloat

    var body: some View {
        Rectangle()
            .fill(.white)
            .colorEffect(ShaderLibrary.haloOrb(
                .float2(diameter * 1.8, diameter * 1.8),
                .float(time), .float(beat), .float(light ? 1 : 0), .float(spread),
                .color(colors[0]), .color(colors[1]), .color(colors[2]), .color(colors[3])))
    }
}
#else
/// watchOS path: the same look drawn with Canvas (no custom Metal shaders on the watch).
private struct OrbLayer: View {
    var time: Double, beat: Double, light: Bool, spread: Double
    var colors: [Color]
    var diameter: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = diameter / 2
            let tint = colors[1]
            // glow
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.7, y: c.y - r * 1.7, width: r * 3.4, height: r * 3.4)),
                     with: .radialGradient(Gradient(colors: [tint.opacity(0.32 + 0.2 * beat), tint.opacity(0.08), .clear]),
                                           center: c, startRadius: 0, endRadius: r * 1.7))
            // ribbons
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: r * 0.05))
                layer.blendMode = .plusLighter
                let specs: [(Double, Double, Double, Double, Double)] = [(2.3, 0.85, 0, 0.15, 1), (2.9, -0.7, 1.9, 0.13, 0.85), (1.9, 0.52, 3.7, 0.11, 1.1)]
                for (i, s) in specs.enumerated() {
                    let amp = 0.24 * (0.75 + 0.3 * beat) * s.4
                    var top = Path(), bottom: [CGPoint] = []
                    for step in 0...40 {
                        let x = -1 + 2 * Double(step) / 40
                        let env = pow(max(0, 1 - x * x), 1.35)
                        let wave1: Double = sin(s.0 * x + time * s.1 + s.2)
                        let wave2: Double = sin(s.0 * 2.1 * x - time * s.1 * 1.35 + s.2 * 1.7)
                        let y0: Double = env * amp * (wave1 + 0.38 * wave2)
                        let h: Double = (s.3 * env + 0.012) * 0.9
                        let px: CGFloat = c.x + CGFloat(x) * r
                        let pt = CGPoint(x: px, y: c.y - CGFloat(y0 + h) * r)
                        if step == 0 { top.move(to: pt) } else { top.addLine(to: pt) }
                        bottom.append(CGPoint(x: px, y: c.y - CGFloat(y0 - h) * r))
                    }
                    for pt in bottom.reversed() { top.addLine(to: pt) }
                    top.closeSubpath()
                    layer.fill(top, with: .color(colors[i].opacity(0.9)))
                }
            }
        }
    }
}
#endif
