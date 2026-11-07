import SwiftUI

/// Pouring pint loading animation. Ported from frontend/src/lib/PourLoader.svelte:
/// same geometry (in fractions of `size`) and the same 4.5s timeline.
struct PourLoader: View {
    var size: CGFloat = 64

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration = 4.5
    private static let beer = Color(hex: 0xf6a623)
    private static let beerDeep = Color(hex: 0xd97a12)
    private static let foam = Color(hex: 0xfffaf0)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvasSize in
                draw(in: &ctx, s: canvasSize.width, time: time)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    // MARK: - Drawing

    private func draw(in ctx: inout GraphicsContext, s: CGFloat, time: Double) {
        let ink = Palette.of(scheme).ink
        let glass = scheme == .dark ? Color(hex: 0x3a2a1c) : Color(hex: 0xe9f3f6)

        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
        }
        func shape(_ rect: CGRect, top: Double, bottom: Double, right: Double? = nil) -> Path {
            let radii = RectangleCornerRadii(
                topLeading: top * s, bottomLeading: bottom * s,
                bottomTrailing: (right ?? bottom) * s, topTrailing: (right ?? top) * s)
            return UnevenRoundedRectangle(cornerRadii: radii).path(in: rect)
        }

        // Timeline values (reduced motion: a static full pint, no stream).
        let t = reduceMotion ? 0.8 : (time / Self.duration).truncatingRemainder(dividingBy: 1)
        let fill = keyframes(t, [(0, 0), (0.08, 0), (0.62, 0.86), (0.86, 0.86), (0.98, 0), (1, 0)])
        let foamScale = keyframes(t, [(0, 0), (0.12, 0), (0.30, 0.55), (0.62, 0.8), (0.72, 1), (0.86, 1), (0.96, 0), (1, 0)])
        let streamTop = keyframes(t, [(0, 0), (0.62, 0), (0.70, 1), (1, 1)])
        let streamBottom = keyframes(t, [(0, 1), (0.10, 0), (1, 0)])

        // Tap + nozzle
        ctx.fill(shape(r(0.32, 0.04, 0.22, 0.08), top: 0.04, bottom: 0.04), with: .color(ink))
        ctx.fill(shape(r(0.39, 0.11, 0.065, 0.06), top: 0, bottom: 0.02), with: .color(ink))

        // Mug: outline, then the glass inside it (0.06 border)
        ctx.fill(shape(r(0.18, 0.30, 0.5, 0.6), top: 0.04, bottom: 0.13), with: .color(ink))
        let inner = r(0.24, 0.36, 0.38, 0.48)
        ctx.fill(shape(inner, top: 0, bottom: 0.07), with: .color(glass))

        // Stream (drawn under the beer so the beer covers it)
        if !reduceMotion {
            let y0 = 0.16 + 0.68 * streamTop
            let y1 = 0.16 + 0.68 * (1 - streamBottom)
            if y1 > y0 {
                ctx.fill(shape(r(0.405, y0, 0.045, y1 - y0), top: 0.03, bottom: 0.03), with: .color(Self.beer))
            }
        }

        // Beer
        let beerH = 0.48 * fill
        let beerTop = 0.84 - beerH
        if beerH > 0 {
            let beerRect = r(0.24, beerTop, 0.38, beerH)
            let beerPath = shape(beerRect, top: 0, bottom: min(0.07, beerH / 2))
            ctx.fill(beerPath, with: .linearGradient(
                Gradient(colors: [Self.beerDeep, Self.beer]),
                startPoint: CGPoint(x: beerRect.midX, y: beerRect.maxY),
                endPoint: CGPoint(x: beerRect.midX, y: beerRect.minY)))

            // Bubbles, clipped to the beer
            if !reduceMotion {
                var bubbles = ctx
                bubbles.clip(to: beerPath)
                let specs: [(x: Double, delay: Double, d: Double)] = [
                    (0.22, 0, 0.03), (0.55, 0.5, 0.022), (0.74, 0.9, 0.03), (0.38, 1.15, 0.02),
                ]
                for b in specs {
                    let p = ((time - b.delay) / 1.4).truncatingRemainder(dividingBy: 1)
                    let phase = p < 0 ? p + 1 : p
                    let opacity = phase < 0.15 ? phase / 0.15 : (1 - phase) / 0.85
                    let x = 0.24 + 0.38 * b.x
                    let y = 0.84 + 0.04 - b.d - 0.45 * phase
                    bubbles.opacity = opacity
                    bubbles.fill(Path(ellipseIn: r(x, y, b.d, b.d)), with: .color(.white.opacity(0.7)))
                }
            }
        }

        // Foam head, riding on the beer and growing up from its base
        if foamScale > 0 {
            var foam = ctx
            let baseY = (beerTop + 0.03) * s
            foam.translateBy(x: 0, y: baseY)
            foam.scaleBy(x: 1, y: foamScale)
            foam.translateBy(x: 0, y: -baseY)
            let fy = beerTop - 0.07
            foam.fill(shape(r(0.22, fy, 0.42, 0.1), top: 0.05, bottom: 0.05), with: .color(Self.foam))
            foam.fill(Path(ellipseIn: r(0.27, fy - 0.05, 0.14, 0.12)), with: .color(Self.foam))
            foam.fill(Path(ellipseIn: r(0.41, fy - 0.07, 0.17, 0.14)), with: .color(Self.foam))
        }

        // Glass highlight
        ctx.fill(shape(r(0.28, 0.42, 0.04, 0.3), top: 0.02, bottom: 0.02), with: .color(.white.opacity(0.65)))

        // Handle: outer shape minus inner, open on the left
        var handle = shape(r(0.63, 0.42, 0.21, 0.32), top: 0, bottom: 0, right: 0.13)
        handle.addPath(shape(r(0.63, 0.48, 0.15, 0.20), top: 0, bottom: 0, right: 0.07))
        ctx.fill(handle, with: .color(ink), style: FillStyle(eoFill: true))
    }

    // MARK: - CSS-style keyframes with ease-in-out per segment

    private func keyframes(_ t: Double, _ stops: [(Double, Double)]) -> Double {
        for i in 1..<stops.count where t <= stops[i].0 {
            let (t0, v0) = stops[i - 1], (t1, v1) = stops[i]
            guard t1 > t0 else { return v1 }
            return v0 + (v1 - v0) * easeInOut((t - t0) / (t1 - t0))
        }
        return stops.last!.1
    }

    /// cubic-bezier(.42, 0, .58, 1), the CSS `ease-in-out` curve.
    private func easeInOut(_ x: Double) -> Double {
        func bez(_ u: Double, _ p1: Double, _ p2: Double) -> Double {
            3 * (1 - u) * (1 - u) * u * p1 + 3 * (1 - u) * u * u * p2 + u * u * u
        }
        var lo = 0.0, hi = 1.0, u = x
        for _ in 0..<20 {
            u = (lo + hi) / 2
            if bez(u, 0.42, 0.58) < x { lo = u } else { hi = u }
        }
        return bez(u, 0, 1)
    }
}

#Preview {
    HStack(spacing: 24) {
        PourLoader(size: 128)
        PourLoader()
        PourLoader(size: 32)
    }
    .padding()
}
