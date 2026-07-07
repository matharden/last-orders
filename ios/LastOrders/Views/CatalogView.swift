import SwiftUI

struct CatalogView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""

    private var p: Palette { Palette.of(scheme) }

    private var filtered: [Drink] {
        guard !query.isEmpty else { return state.catalog }
        let q = query.lowercased()
        return state.catalog.filter {
            $0.drink.lowercased().contains(q) || $0.brewery.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow("THE CELLAR · \(state.catalog.count) beers")

                searchField

                VStack(spacing: 0) {
                    if filtered.isEmpty {
                        Text("No beers found.")
                            .font(.mono(13))
                            .foregroundStyle(p.ink3)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, drink in
                            beerRow(drink)
                            if i < filtered.count - 1 {
                                Divider().overlay(p.line).padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .card()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .refreshable { await state.refresh() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(p.ink3)
            TextField("Search beers, brewery…", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(p.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .card(radius: 12)
    }

    private func beerRow(_ drink: Drink) -> some View {
        HStack(spacing: 12) {
            Button {
                state.logDraft = .quickLog(drink)
            } label: {
                labelArt(drink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quick-log \(drink.drink)")

            VStack(alignment: .leading, spacing: 2) {
                if !drink.brewery.isEmpty {
                    Text(drink.brewery.uppercased())
                        .font(.mono(10, .medium))
                        .tracking(1.2)
                        .foregroundStyle(p.ink3)
                        .lineLimit(1)
                }
                Text(drink.drink)
                    .font(.serif(17, .medium))
                    .foregroundStyle(p.ink)
                    .lineLimit(1)
                if drink.abv > 0 {
                    Text("\(Units.fmtNum(drink.abv))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(p.amber)
                }
            }
            Spacer(minLength: 8)
            if drink.rating > 0 {
                Text(String(repeating: "★", count: drink.rating) + String(repeating: "☆", count: 5 - drink.rating))
                    .font(.system(size: 14))
                    .foregroundStyle(p.gold)
            } else {
                Text("· · ·")
                    .font(.mono(14))
                    .foregroundStyle(p.ink3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            state.editingDrink = drink
        }
    }

    private func labelArt(_ drink: Drink) -> some View {
        ZStack {
            if let url = URL(string: drink.image), !drink.image.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Units.labelColor(drink.drink, dark: scheme == .dark)
                }
            } else {
                Units.labelColor(drink.drink, dark: scheme == .dark)
                Text(drink.drink.uppercased())
                    .font(.mono(7.5, .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.25))
            }
        }
        .frame(width: 50, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
