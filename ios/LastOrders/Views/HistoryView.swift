import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    private var p: Palette { Palette.of(scheme) }

    /// Entries grouped by date, newest day first, preserving sheet order within a day.
    private var groups: [(date: String, entries: [EnrichedEntry])] {
        var map: [String: [EnrichedEntry]] = [:]
        for e in state.sortedLog {
            map[e.entry.date, default: []].append(e)
        }
        return map.keys.sorted(by: >).map { (date: $0, entries: map[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Eyebrow("THE JOURNAL")

                if groups.isEmpty {
                    Text("No entries yet. Tap + to log your first drink.")
                        .font(.mono(13))
                        .foregroundStyle(p.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }

                ForEach(groups, id: \.date) { group in
                    dayGroup(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .refreshable { await state.refresh() }
    }

    private func dayGroup(_ group: (date: String, entries: [EnrichedEntry])) -> some View {
        let dayUnits = group.entries.reduce(0) { $0 + $1.units }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Units.fmtDate(group.date, format: "d MMMM"))
                    .font(.serif(19, .semibold))
                    .foregroundStyle(p.ink)
                Text(Units.fmtWeekday(group.date))
                    .font(.mono(10, .medium))
                    .tracking(1.4)
                    .foregroundStyle(p.ink3)
                Spacer()
                Text(String(format: "%.1f units", dayUnits))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(p.amber)
            }

            DashedRule()

            VStack(spacing: 0) {
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { i, entry in
                    Button {
                        state.logDraft = .edit(entry)
                    } label: {
                        JournalRow(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < group.entries.count - 1 {
                        Divider().overlay(p.line)
                    }
                }
            }
            .padding(.horizontal, 16)
            .card()
        }
    }
}
