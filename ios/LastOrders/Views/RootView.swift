import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        @Bindable var state = state
        let p = Palette.of(scheme)

        ZStack(alignment: .bottom) {
            p.paper.ignoresSafeArea()

            Group {
                if state.isLoading {
                    VStack {
                        Spacer()
                        PourLoader()
                        Spacer()
                    }
                } else {
                    switch state.activeTab {
                    case .home: HomeView()
                    case .journal: HistoryView()
                    case .stats: StatsView()
                    case .cellar: CatalogView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNav()
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let toast = state.toast {
                    Text(toast)
                        .font(.mono(12, .semibold))
                        .foregroundStyle(p.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .card(radius: 22)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let error = state.errorMessage {
                    ErrorBanner(message: error)
                }
            }
            .padding(.top, 6)
            .padding(.horizontal, 20)
            .animation(.spring(duration: 0.35), value: state.toast)
        }
        .sheet(item: $state.logDraft) { draft in
            LogSheetView(draft: draft)
        }
        .sheet(item: $state.editingDrink) { drink in
            DrinkEditView(drink: drink)
        }
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
        }
        .task {
            if !state.isConfigured {
                state.showSettings = true
            }
            await state.refresh()
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        HStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(p.ink)
            Spacer(minLength: 4)
            Button("Settings") { state.showSettings = true }
                .font(.mono(11, .semibold))
                .foregroundStyle(p.amber)
            Button {
                state.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(p.ink3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .card(radius: 12)
    }
}

struct BottomNav: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @State private var capPops = 0

    var body: some View {
        let p = Palette.of(scheme)
        HStack(alignment: .bottom, spacing: 0) {
            tab(.home, icon: "house", label: "Home")
            tab(.journal, icon: "mug", label: "Bar tab")

            Button {
                // Let the cap pop up at the bottom edge before the sheet slides up.
                capPops += 1
                Task {
                    try? await Task.sleep(for: .milliseconds(160))
                    state.logDraft = LogDraft()
                }
            } label: {
                BottleCap(p: p, size: 62)
                    .keyframeAnimator(initialValue: 0.0, trigger: capPops) { cap, angle in
                        // hinged near the top, so the bottom edge lifts toward you
                        cap.rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0),
                                             anchor: UnitPoint(x: 0.5, y: 0.08), perspective: 0.5)
                    } keyframes: { _ in
                        CubicKeyframe(30, duration: 0.15)
                        CubicKeyframe(0, duration: 0.27)
                    }
                    .shadow(color: p.amber.opacity(0.55), radius: 11, y: 6)
            }
            .buttonStyle(CapPressStyle())
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Put on tab")

            tab(.stats, icon: "chart.bar", label: "Measures")
            tab(.cellar, icon: "archivebox", label: "Cellar")
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18, style: .continuous)
                .fill(p.card)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18, style: .continuous)
                        .stroke(p.cardEdge, lineWidth: 1)
                )
                .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.18), radius: 11, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ target: AppState.Tab, icon: String, label: String) -> some View {
        let p = Palette.of(scheme)
        let active = state.activeTab == target
        return Button {
            state.activeTab = target
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                Text(label.uppercased())
                    .font(.mono(9, .medium))
                    .tracking(1.1)
            }
            .foregroundStyle(active ? p.amber : p.ink3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottle cap add button
// Mirrors the .fab SVG in frontend/src/lib/BottomNav.svelte; all measurements are in
// that SVG's 100×100 viewBox units, scaled by `size / 100`.

/// Crimped skirt of a crown cap: rounded flutes around the rim.
private struct CrownCapShape: Shape {
    var flutes = 21

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func pt(_ r: CGFloat, _ a: CGFloat) -> CGPoint {
            CGPoint(x: c.x + r * s * sin(a), y: c.y - r * s * cos(a))
        }
        let step = 2 * .pi / CGFloat(flutes)
        var path = Path()
        path.move(to: pt(42.5, 0))
        for i in 0..<flutes {
            path.addQuadCurve(to: pt(42.5, CGFloat(i + 1) * step),
                              control: pt(51.5, (CGFloat(i) + 0.5) * step))
        }
        path.closeSubpath()
        return path
    }
}

/// A crown bottle cap seen from above, printed "Put on tab".
private struct BottleCap: View {
    let p: Palette
    let size: CGFloat
    private let flutes = 21

    var body: some View {
        let s = size / 100
        let metal = RadialGradient(
            stops: [
                .init(color: Color(hex: 0xfff3d2), location: 0),
                .init(color: p.gold, location: 0.28),
                .init(color: p.amber, location: 0.75),
                .init(color: p.amber2, location: 1),
            ],
            center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: 75 * s
        )

        ZStack {
            // crimped skirt
            CrownCapShape(flutes: flutes).fill(metal)
            CrownCapShape(flutes: flutes)
                .stroke(p.amber2, style: StrokeStyle(lineWidth: 0.8 * s, lineJoin: .round))
            ForEach(0..<flutes, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0xfff6dc).opacity(0.3))
                    .frame(width: 1.2 * s, height: 6 * s)
                    .offset(y: -41 * s)
                    .rotationEffect(.degrees((Double(i) + 0.5) * 360 / Double(flutes)))
            }
            // fold where the skirt meets the crown
            Circle()
                .stroke(p.amber2.opacity(0.55), lineWidth: 1.2 * s)
                .frame(width: 77 * s, height: 77 * s)

            // printed crown
            Circle().fill(Color(hex: 0x3a1f10)).frame(width: 72 * s, height: 72 * s)
            Circle().stroke(p.gold, lineWidth: 1 * s).frame(width: 65 * s, height: 65 * s)
            Circle().stroke(p.gold, lineWidth: 0.4 * s).frame(width: 62 * s, height: 62 * s)

            ArcText(text: "PUT ON", radius: 25.8 * s, fontSize: 9.5 * s, color: p.gold)

            Rectangle().fill(p.gold).frame(width: 34 * s, height: 0.6 * s).offset(y: -3 * s)
            Rectangle().fill(p.gold).frame(width: 34 * s, height: 0.6 * s).offset(y: 14 * s)
            Text("Tab")
                .font(.serif(19 * s, .semibold))
                .foregroundStyle(Color(hex: 0xf6e7c4))
                .offset(y: 5 * s)
            Text("★ ★ ★")
                .font(.system(size: 5 * s))
                .tracking(1.5 * s)
                .foregroundStyle(p.gold)
                .offset(y: 23.3 * s)
        }
        .frame(width: size, height: size)
    }
}

/// Monospaced capitals set around the top of a circle, centred on 12 o'clock.
private struct ArcText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat
    let color: Color

    var body: some View {
        let chars = Array(text)
        // Monospaced advance (~0.6em) plus 0.12em tracking, as an angle on the arc.
        let step = Double(fontSize * 0.72 / radius) * 180 / .pi
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                Text(String(chars[i]))
                    .font(.mono(fontSize, .semibold))
                    .foregroundStyle(color)
                    .offset(y: -radius)
                    .rotationEffect(.degrees((Double(i) - Double(chars.count - 1) / 2) * step))
            }
        }
    }
}

/// Press feedback while the finger is down; the pop itself runs on tap.
private struct CapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
