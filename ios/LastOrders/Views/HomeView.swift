import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme
    @State private var weekOffset = 0

    private var p: Palette { Palette.of(scheme) }

    var body: some View {
        let enriched = state.enrichedLog
        let (mon, sun) = Units.weekRange(offset: weekOffset)
        let entries = enriched.filter { $0.entry.date >= mon && $0.entry.date <= sun }
        let weekUnits = entries.reduce(0) { $0 + $1.units }
        let weekDrinks = entries.reduce(0) { $0 + $1.entry.amount }
        let daysWithEntries = Set(entries.map(\.entry.date))

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                measureHead(mon: mon)
                    .padding(.bottom, 10)

                heroCard(mon: mon, sun: sun, units: weekUnits, drinks: weekDrinks, days: daysWithEntries)
                    .padding(.bottom, 12)

                statGrid(units: weekUnits, drinks: weekDrinks, days: daysWithEntries.count)
                    .padding(.bottom, 20)

                Eyebrow("LAST POURED")
                    .padding(.bottom, 10)

                lastPoured
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .refreshable { await state.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("THE TASTING JOURNAL")
                Text("Last orders")
                    .font(.serif(24, .semibold))
                    .foregroundStyle(p.ink)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(Units.fmtDate(Units.todayISO(), format: "d MMM yyyy"))
                    .font(.mono(11))
                    .foregroundStyle(p.ink3)
                Button {
                    state.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(p.ink3)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Measure head (label + week nav)

    private func measureHead(mon: String) -> some View {
        let earliestWeek = state.enrichedLog.map(\.entry.date).min().map(Units.weekMonday)
        let canPrev = earliestWeek != nil && mon > earliestWeek!
        let canNext = weekOffset < 0
        let label: String = switch weekOffset {
        case 0: "THIS WEEK'S MEASURE"
        case -1: "LAST WEEK'S MEASURE"
        default: "WEEK OF \(Units.fmtDate(mon).uppercased())"
        }

        return HStack {
            Eyebrow(label)
            Spacer()
            HStack(spacing: 6) {
                navButton("arrow.left", enabled: canPrev) { weekOffset -= 1 }
                navButton("arrow.right", enabled: canNext) { weekOffset += 1 }
            }
        }
    }

    private func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(enabled ? p.amber : p.ink3.opacity(0.4))
                .frame(width: 26, height: 26)
                .background(p.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.cardEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Hero card

    private func heroCard(mon: String, sun: String, units: Double, drinks: Double, days: Set<String>) -> some View {
        let weekDates: [String] = (0..<7).compactMap { i in
            guard let d = Units.parse(mon),
                  let day = Units.utcCalendar.date(byAdding: .day, value: i, to: d) else { return nil }
            return Units.iso(day)
        }
        let rangeLabel = "\(Units.fmtDate(mon)) – \(Units.fmtDate(sun))"

        return VStack(alignment: .leading, spacing: 6) {
            Text("UK UNITS · \(rangeLabel)")
                .font(.mono(10))
                .foregroundStyle(p.ink3)

            (Text(String(format: "%.1f", units))
                .font(.serif(60, .medium))
                .foregroundStyle(p.ink)
             + Text(" / \(Int(Units.weeklyTarget))")
                .font(.serif(28, .medium))
                .foregroundStyle(p.amber))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(Units.fmtNum(drinks)) drinks across \(days.count) evening\(days.count == 1 ? "" : "s")…")
                .font(.system(size: 13.5))
                .foregroundStyle(p.ink2)
                .padding(.bottom, 8)

            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    Capsule()
                        .fill(days.contains(date) ? AnyShapeStyle(p.barGradient) : AnyShapeStyle(p.paper2))
                        .overlay(Capsule().stroke(p.line, lineWidth: days.contains(date) ? 0 : 1))
                        .frame(height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16))
        .background(alignment: .topTrailing) {
            Circle()
                .stroke(p.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 130, height: 130)
                .offset(x: 40, y: -40)
                .opacity(0.5)
        }
        .card(radius: 16)
    }

    // MARK: - Stat tiles

    private func statGrid(units: Double, drinks: Double, days: Int) -> some View {
        let avgUnits = drinks > 0 && days > 0 ? units / Double(days) : 0
        return HStack(spacing: 10) {
            StatTile(value: Units.fmtNum(drinks), label: "Drinks")
            StatTile(value: String(format: "%.1f", avgUnits), label: "Avg units")
            StatTile(value: dryDays, label: "Dry days")
        }
    }

    private var dryDays: String {
        guard let last = state.enrichedLog.map(\.entry.date).max(),
              let days = Units.daysBetween(last, Units.todayISO()) else { return "—" }
        return "\(max(0, days))"
    }

    // MARK: - Last poured

    private var lastPoured: some View {
        let recent = Array(state.sortedLog.prefix(4))
        return VStack(spacing: 0) {
            if recent.isEmpty {
                Text("No entries yet — tap + to log.")
                    .font(.mono(13))
                    .foregroundStyle(p.ink3)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { i, entry in
                    JournalRow(entry: entry)
                    if i < recent.count - 1 {
                        Divider().overlay(p.line)
                    }
                }
            }
            if state.enrichedLog.count > 4 {
                Divider().overlay(p.line)
                Button {
                    state.activeTab = .journal
                } label: {
                    Text("READ THE FULL JOURNAL →")
                        .font(.mono(11, .semibold))
                        .tracking(1.5)
                        .foregroundStyle(p.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .card()
    }
}
