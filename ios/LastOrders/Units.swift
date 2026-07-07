import SwiftUI

/// Direct port of frontend/src/lib/units.js — keep the two in sync.
enum Units {
    static let sizeLabels: [Int: String] = [100: "Shot", 330: "Small", 400: "Medium", 500: "Large", 568: "Pint"]
    static let sizes = [100, 330, 400, 500, 568]
    static let amounts: [Double] = [1, 1.5, 2, 3]
    static let weeklyTarget: Double = 14

    static let abvOverrides: [String: Double] = [
        "Side Pocket": 4.4, "Ale": 4.5, "Peroni Capri": 4.2, "Camden Ale": 4.0,
        "Badger Master Stoat": 5.0, "Badger Cranbourne Poacher": 5.6,
        "Badger Thirsty Ferret": 4.4, "Moth: Old Fashioned": 28, "Tribute": 4.2,
        "Neck Oil": 4.3, "Hazy Jane": 5.0, "Doombar": 4.3, "London Pride": 4.7,
    ]

    static func resolveAbv(_ drinkName: String, catalog: [Drink]) -> Double {
        let lower = drinkName.lowercased()
        if let hit = catalog.first(where: {
            let c = $0.drink.lowercased()
            return !c.isEmpty && (c == lower || lower.contains(c))
        }) {
            return hit.abv
        }
        if let override = abvOverrides[drinkName] { return override }
        return 4.5
    }

    static func units(drink: String, size: Int, amount: Double, catalog: [Drink]) -> Double {
        resolveAbv(drink, catalog: catalog) * Double(size) * amount / 1000
    }

    // MARK: - Dates (all on yyyy-MM-dd strings, UTC, so they sort and compare lexicographically)

    static let utc = TimeZone(identifier: "UTC")!

    static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal
    }()

    private static let isoUTC: DateFormatter = makeFormatter("yyyy-MM-dd", timeZone: utc)
    private static let isoLocal: DateFormatter = makeFormatter("yyyy-MM-dd", timeZone: .current)

    private static func makeFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.timeZone = timeZone
        df.dateFormat = format
        return df
    }

    static func parse(_ iso: String) -> Date? { isoUTC.date(from: iso) }
    static func iso(_ date: Date) -> String { isoUTC.string(from: date) }
    static func todayISO() -> String { isoLocal.string(from: Date()) }

    private static var displayFormatters: [String: DateFormatter] = [:]

    static func fmtDate(_ iso: String, format: String = "d MMM") -> String {
        guard let d = parse(iso) else { return iso }
        let df: DateFormatter
        if let cached = displayFormatters[format] {
            df = cached
        } else {
            df = makeFormatter(format, timeZone: utc)
            displayFormatters[format] = df
        }
        return df.string(from: d)
    }

    static func fmtWeekday(_ iso: String) -> String {
        fmtDate(iso, format: "EEE").uppercased()
    }

    /// ISO date of the Monday of the week containing the given date.
    static func weekMonday(_ isoDate: String) -> String {
        guard let d = parse(isoDate) else { return isoDate }
        let weekday = utcCalendar.component(.weekday, from: d) // 1 = Sunday … 7 = Saturday
        let offset = (weekday + 5) % 7                          // Monday = 0
        return iso(utcCalendar.date(byAdding: .day, value: -offset, to: d) ?? d)
    }

    static func weekRange(offset: Int) -> (mon: String, sun: String) {
        let monISO = weekMonday(todayISO())
        guard var d = parse(monISO) else { return (monISO, monISO) }
        d = utcCalendar.date(byAdding: .day, value: offset * 7, to: d) ?? d
        let mon = iso(d)
        let sun = iso(utcCalendar.date(byAdding: .day, value: 6, to: d) ?? d)
        return (mon, sun)
    }

    static func daysBetween(_ fromISO: String, _ toISO: String) -> Int? {
        guard let from = parse(fromISO), let to = parse(toISO) else { return nil }
        return utcCalendar.dateComponents([.day], from: from, to: to).day
    }

    // MARK: - Aggregations

    struct WeekBucket: Identifiable {
        var label: String   // Monday ISO date
        var units: Double
        var drinks: Double
        var id: String { label }
    }

    static func weeklyBuckets(log: [LogEntry], catalog: [Drink]) -> [WeekBucket] {
        var weeks: [String: WeekBucket] = [:]
        for e in log {
            let key = weekMonday(e.date)
            var w = weeks[key] ?? WeekBucket(label: key, units: 0, drinks: 0)
            w.units += units(drink: e.drink, size: e.size, amount: e.amount, catalog: catalog)
            w.drinks += e.amount
            weeks[key] = w
        }
        return weeks.values.sorted { $0.label < $1.label }
    }

    struct RankItem: Identifiable {
        var name: String
        var count: Double
        var id: String { name }
    }

    private static let breweryFallbacks: [(keyword: String, brewery: String)] = [
        ("badger", "Badger"), ("camden", "Camden Town Brewery"), ("neck oil", "Beavertown"),
        ("hazy jane", "Brewdog"), ("london pride", "Fullers"), ("doombar", "Sharps"),
        ("peroni", "Peroni"), ("tribute", "St Austell"), ("moth", "Moth"),
    ]

    static func topBreweries(log: [LogEntry], catalog: [Drink]) -> [RankItem] {
        var map: [String: Double] = [:]
        var order: [String] = []
        for e in log {
            let lower = e.drink.lowercased()
            var brewery = catalog.first(where: {
                let c = $0.drink.lowercased()
                return !c.isEmpty && lower.contains(c)
            })?.brewery ?? ""
            if brewery.isEmpty {
                brewery = breweryFallbacks.first(where: { lower.contains($0.keyword) })?.brewery ?? "Other"
            }
            if map[brewery] == nil { order.append(brewery) }
            map[brewery, default: 0] += e.amount
        }
        return order.map { RankItem(name: $0, count: map[$0] ?? 0) }
            .sorted { $0.count > $1.count }
    }

    static func topDrinks(log: [LogEntry]) -> [RankItem] {
        var map: [String: Double] = [:]
        var order: [String] = []
        for e in log {
            if map[e.drink] == nil { order.append(e.drink) }
            map[e.drink, default: 0] += e.amount
        }
        return order.map { RankItem(name: $0, count: map[$0] ?? 0) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Presentation helpers

    /// Deterministic warm hue per drink name (same hash as the web app).
    static func labelColor(_ name: String, dark: Bool) -> Color {
        var h = 0
        for unit in name.utf16 { h = (h * 31 + Int(unit)) % 360 }
        let hue = Double((h % 40) + 22)
        return dark ? Color(hsl: hue, 0.66, 0.46) : Color(hsl: hue, 0.70, 0.38)
    }

    static func drinkInitials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first else { return "" }
        if words.count == 1 { return String(first.prefix(2)).uppercased() }
        let initials = [first.first, words[1].first].compactMap { $0 }
        return String(initials).uppercased()
    }

    /// "1", "1.5" — whole numbers without the trailing .0, like JS number display.
    static func fmtNum(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
