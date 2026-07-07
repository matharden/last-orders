import SwiftUI

struct StatsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    private var p: Palette { Palette.of(scheme) }

    var body: some View {
        let enriched = state.enrichedLog
        let allUnits = enriched.reduce(0) { $0 + $1.units }
        let allDrinks = enriched.reduce(0) { $0 + $1.entry.amount }
        let allDays = Set(enriched.map(\.entry.date)).count
        // Newest week first, matching the web app's reversed chart.
        let weekly = Array(Units.weeklyBuckets(log: state.log, catalog: state.catalog).reversed())
        let breweries = Units.topBreweries(log: state.log, catalog: state.catalog)
        let drinks = Units.topDrinks(log: state.log)

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("ALL TIME")
                HStack(spacing: 10) {
                    StatTile(value: String(format: "%.1f", allUnits), label: "Units")
                    StatTile(value: String(format: "%.0f", allDrinks), label: "Drinks")
                    StatTile(value: "\(allDays)", label: "Days out")
                }
                .padding(.bottom, 10)

                Eyebrow("UNITS BY WEEK")
                weeklyChart(weekly)
                    .padding(.bottom, 10)

                Eyebrow("FAVOURITE BREWERIES")
                rankCard(breweries)
                    .padding(.bottom, 10)

                Eyebrow("MOST POURED")
                rankCard(drinks)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .refreshable { await state.refresh() }
    }

    private func weeklyChart(_ weeks: [Units.WeekBucket]) -> some View {
        let maxUnits = max(1, weeks.map(\.units).max() ?? 1)
        return Group {
            if weeks.isEmpty {
                emptyLabel
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(weeks) { week in
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", week.units))
                                    .font(.serif(12, .semibold))
                                    .foregroundStyle(p.ink)
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 7, bottomLeadingRadius: 3,
                                    bottomTrailingRadius: 3, topTrailingRadius: 7,
                                    style: .continuous
                                )
                                .fill(p.barGradientVertical)
                                .frame(width: 34, height: max(4, week.units / maxUnits * 150))
                                Text(Units.fmtDate(week.label, format: "d MMM"))
                                    .font(.mono(9))
                                    .foregroundStyle(p.ink3)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func rankCard(_ items: [Units.RankItem]) -> some View {
        let maxCount = max(1, items.map(\.count).max() ?? 1)
        return VStack(spacing: 0) {
            if items.isEmpty {
                emptyLabel
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    RankRow(index: i + 1, name: item.name, count: item.count, max: maxCount)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .card()
    }

    private var emptyLabel: some View {
        Text("No data yet.")
            .font(.mono(13))
            .foregroundStyle(p.ink3)
            .padding(.vertical, 12)
    }
}
