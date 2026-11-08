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

    var body: some View {
        let p = Palette.of(scheme)
        HStack(alignment: .bottom, spacing: 0) {
            tab(.home, icon: "house", label: "Home")
            tab(.journal, icon: "mug", label: "Bar tab")

            Button {
                state.logDraft = LogDraft()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(p.fabGradient))
                    .shadow(color: p.amber.opacity(0.55), radius: 11, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Log a drink")

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
