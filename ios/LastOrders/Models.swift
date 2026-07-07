import Foundation

struct Drink: Codable, Identifiable, Hashable {
    var id: Int
    var brewery: String
    var drink: String
    var abv: Double
    var rating: Int
    var image: String
    var notes: String
}

struct LogEntry: Codable, Identifiable, Hashable {
    var id: String
    var date: String   // yyyy-MM-dd
    var drink: String
    var amount: Double
    var size: Int
    var notes: String
}

/// Body for POST /api/log and PUT /api/log/{id}
struct LogPayload: Codable {
    var date: String
    var drink: String
    var amount: Double
    var size: Int
    var notes: String
}

/// Body for PUT /api/catalog/{id}
struct DrinkPayload: Codable {
    var brewery: String
    var drink: String
    var abv: Double
    var rating: Int
    var image: String
    var notes: String
}

/// Log entry joined with catalog data (abv, units, image), mirroring the web app's enrichedLog store.
struct EnrichedEntry: Identifiable, Hashable {
    var entry: LogEntry
    var abv: Double
    var units: Double
    var image: String
    var id: String { entry.id }
}
