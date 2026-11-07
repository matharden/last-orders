import SwiftUI
import Observation

/// Draft used by the log sheet — nil id means "create", otherwise it edits that entry.
struct LogDraft: Identifiable {
    let id = UUID()
    var entryID: String?
    var drink = ""
    var abv: Double?
    var size = 330
    var amount: Double = 1
    var notes = ""
    var date = Units.todayISO()

    static func quickLog(_ drink: Drink) -> LogDraft {
        LogDraft(entryID: nil, drink: drink.drink, abv: drink.abv, size: 568, amount: 1)
    }

    static func edit(_ e: EnrichedEntry) -> LogDraft {
        LogDraft(
            entryID: e.entry.id,
            drink: e.entry.drink,
            abv: e.abv,
            size: e.entry.size > 0 ? e.entry.size : 500,
            amount: e.entry.amount > 0 ? e.entry.amount : 1,
            notes: e.entry.notes,
            date: e.entry.date
        )
    }
}

@MainActor
@Observable
final class AppState {
    static let defaultServerURL = "https://boozer-iv3tequcoa-uc.a.run.app"

    enum Tab: String, CaseIterable {
        case home, journal, stats, cellar
    }

    // MARK: - Settings (persisted)

    var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? AppState.defaultServerURL {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    /// Email of the signed-in Google account (display only; the token is what authenticates).
    var email: String = UserDefaults.standard.string(forKey: "email") ?? "" {
        didSet { UserDefaults.standard.set(email, forKey: "email") }
    }

    /// Signed session token from the server, kept in the Keychain.
    var authToken: String? = TokenStore.load()

    var isSignedIn: Bool { authToken != nil }

    var baseURL: URL? {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmedURL), url.scheme != nil else { return nil }
        return url
    }

    /// Server page that starts Google sign-in and redirects back to lastorders://auth.
    var loginURL: URL? {
        guard let baseURL else { return nil }
        var comps = URLComponents(url: baseURL.appending(path: "login"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "app", value: "ios")]
        return comps?.url
    }

    func completeSignIn(callbackURL: URL) -> Bool {
        guard let cb = AuthCallback(url: callbackURL) else { return false }
        TokenStore.save(cb.token)
        authToken = cb.token
        email = cb.email
        errorMessage = nil
        return true
    }

    func signOut() {
        TokenStore.clear()
        authToken = nil
        email = ""
        catalog = []
        log = []
    }

    // MARK: - Data

    var catalog: [Drink] = []
    var log: [LogEntry] = []
    var isLoading = false
    var errorMessage: String?
    var toast: String?

    // MARK: - UI state

    var activeTab: Tab = .home
    var logDraft: LogDraft?
    var editingDrink: Drink?
    var showSettings = false

    var isConfigured: Bool { api != nil }

    var api: APIClient? {
        // Re-read the Keychain: APIClient may have stored a renewed token.
        guard let url = baseURL, let token = TokenStore.load() ?? authToken else { return nil }
        return APIClient(baseURL: url, token: token)
    }

    var enrichedLog: [EnrichedEntry] {
        log.map { e in
            let match = catalog.first { $0.drink.lowercased() == e.drink.lowercased() }
            return EnrichedEntry(
                entry: e,
                abv: Units.resolveAbv(e.drink, catalog: catalog),
                units: Units.units(drink: e.drink, size: e.size, amount: e.amount, catalog: catalog),
                image: match?.image ?? ""
            )
        }
    }

    /// Log sorted newest date first, preserving sheet order within a day (matches the web app).
    var sortedLog: [EnrichedEntry] {
        enrichedLog.enumerated()
            .sorted { a, b in
                if a.element.entry.date != b.element.entry.date {
                    return a.element.entry.date > b.element.entry.date
                }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    // MARK: - Actions

    func refresh() async {
        guard let api else {
            errorMessage = "Sign in with Google in Settings."
            isLoading = false
            return
        }
        if log.isEmpty && catalog.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            async let catalogTask = api.fetchCatalog()
            async let logTask = api.fetchLog()
            catalog = try await catalogTask
            log = try await logTask
            errorMessage = nil
        } catch {
            errorMessage = friendly(error)
        }
    }

    private func refreshQuietly() {
        Task { await refresh() }
    }

    @discardableResult
    func saveLog(_ draft: LogDraft) async -> Bool {
        guard let api else { return false }
        let payload = LogPayload(
            date: draft.date, drink: draft.drink, amount: draft.amount,
            size: draft.size, notes: draft.notes
        )
        do {
            if let entryID = draft.entryID {
                try await api.updateLog(id: entryID, payload)
                if let i = log.firstIndex(where: { $0.id == entryID }) {
                    log[i] = LogEntry(id: entryID, date: draft.date, drink: draft.drink,
                                      amount: draft.amount, size: draft.size, notes: draft.notes)
                }
            } else {
                let created = try await api.addLog(payload)
                log.insert(created, at: 0)
            }
            showToast("Logged — cheers!")
            refreshQuietly() // the server may have added a new drink to the catalog
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    @discardableResult
    func deleteLog(id: String) async -> Bool {
        guard let api else { return false }
        do {
            try await api.deleteLog(id: id)
            log.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    @discardableResult
    func saveCatalog(id: Int, payload: DrinkPayload) async -> Bool {
        guard let api else { return false }
        do {
            let updated = try await api.updateCatalog(id: id, payload)
            if let i = catalog.firstIndex(where: { $0.id == id }) {
                catalog[i] = updated
            }
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    /// Returns an error message on failure, nil on success (409 means the drink is used in the log).
    func deleteCatalog(id: Int) async -> String? {
        guard let api else { return "Not configured" }
        do {
            try await api.deleteCatalog(id: id)
            catalog.removeAll { $0.id == id }
            return nil
        } catch {
            return friendly(error)
        }
    }

    func uploadImage(_ data: Data, filename: String) async throws -> String {
        guard let api else { throw APIError(status: 0, message: "Not configured") }
        return try await api.upload(imageData: data, filename: filename)
    }

    // MARK: - Toast

    private var toastTask: Task<Void, Never>?

    func showToast(_ message: String) {
        withAnimation { toast = message }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.9))
            if !Task.isCancelled {
                withAnimation { toast = nil }
            }
        }
    }

    private func friendly(_ error: Error) -> String {
        if let apiError = error as? APIError {
            if apiError.status == 401 {
                // Token rejected (expired or the server's key changed): sign out so Settings offers sign-in.
                signOut()
                return "Signed out — sign in again in Settings."
            }
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }
}
