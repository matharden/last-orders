import SwiftUI

/// Ported from frontend/src/app.css — the :root[data-theme] custom properties.
struct Palette {
    let paper: Color
    let paper2: Color
    let card: Color
    let cardEdge: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let amber: Color
    let amber2: Color
    let gold: Color
    let stout: Color
    let good: Color
    let line: Color

    static let light = Palette(
        paper: Color(hex: 0xf3e7cf), paper2: Color(hex: 0xefe0c2),
        card: Color(hex: 0xfbf4e3), cardEdge: Color(hex: 0xe3d3ad),
        ink: Color(hex: 0x241c10), ink2: Color(hex: 0x6a5b40), ink3: Color(hex: 0x9c8a66),
        amber: Color(hex: 0xb0640f), amber2: Color(hex: 0x8a4e0c), gold: Color(hex: 0xcf9322),
        stout: Color(hex: 0x3a2a18), good: Color(hex: 0x4f7a3a), line: Color(hex: 0xdcc89c)
    )

    static let dark = Palette(
        paper: Color(hex: 0x15110a), paper2: Color(hex: 0x1f190f),
        card: Color(hex: 0x1d1810), cardEdge: Color(hex: 0x36291a),
        ink: Color(hex: 0xf1e6cf), ink2: Color(hex: 0xb6a584), ink3: Color(hex: 0x7e7053),
        amber: Color(hex: 0xe0922f), amber2: Color(hex: 0xb06a16), gold: Color(hex: 0xedb24c),
        stout: Color(hex: 0x0e0a05), good: Color(hex: 0x8bb863), line: Color(hex: 0x33271a)
    )

    static func of(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }

    var fabGradient: RadialGradient {
        RadialGradient(colors: [gold, amber], center: UnitPoint(x: 0.6, y: 0.4), startRadius: 2, endRadius: 44)
    }

    var barGradient: LinearGradient {
        LinearGradient(colors: [gold, amber], startPoint: .leading, endPoint: .trailing)
    }

    var barGradientVertical: LinearGradient {
        LinearGradient(colors: [amber, gold], startPoint: .bottom, endPoint: .top)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }

    /// CSS hsl() equivalent (hue in degrees, saturation/lightness 0–1).
    init(hsl hue: Double, _ saturation: Double, _ lightness: Double) {
        let v = lightness + saturation * min(lightness, 1 - lightness)
        let s = v == 0 ? 0 : 2 * (1 - lightness / v)
        self.init(hue: hue / 360, saturation: s, brightness: v)
    }
}

// Newsreader (serif) and Spline Sans Mono map to the system serif and monospaced designs.
extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Shared styling

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        let p = Palette.of(scheme)
        content
            .background(p.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(p.cardEdge, lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 9, y: 5)
    }
}

extension View {
    func card(radius: CGFloat = 14) -> some View {
        modifier(CardStyle(radius: radius))
    }
}

/// The mono uppercase amber section label used across every screen.
struct Eyebrow: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(10.5, .semibold))
            .tracking(2.7)
            .foregroundStyle(Palette.of(scheme).amber)
    }
}
