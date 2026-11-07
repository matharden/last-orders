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

    // MARK: - Saves (optimistic)
    //
    // Saves update the screen immediately and go to the server in the background.
    // If the server rejects one, the change is rolled back and an error shown.
    // New entries get a temporary id until the server replies; edits/deletes of
    // an entry that's still being created wait for its real id.

    private var pendingCreates: [String: Task<String?, Never>] = [:]

    private func resolveID(_ id: String) async -> String? {
        if let task = pendingCreates[id] { return await task.value }
        return id
    }

    private func refreshCatalogIfNew(_ drinkName: String) {
        let name = drinkName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty,
              !catalog.contains(where: { $0.drink.trimmingCharacters(in: .whitespaces).lowercased() == name })
        else { return }
        guard let api else { return }
        Task {
            if let fresh = try? await api.fetchCatalog() { catalog = fresh }
        }
    }

    @discardableResult
    func saveLog(_ draft: LogDraft) async -> Bool {
        guard let api else { return false }
        let payload = LogPayload(
            date: draft.date, drink: draft.drink, amount: draft.amount,
            size: draft.size, notes: draft.notes
        )
        if let entryID = draft.entryID {
            guard let i = log.firstIndex(where: { $0.id == entryID }) else { return false }
            let previous = log[i]
            log[i] = LogEntry(id: entryID, date: draft.date, drink: draft.drink,
                              amount: draft.amount, size: draft.size, notes: draft.notes)
            showToast("Logged — cheers!")
            Task {
                guard let realID = await resolveID(entryID) else { return }
                do {
                    try await api.updateLog(id: realID, payload)
                    refreshCatalogIfNew(draft.drink)
                } catch {
                    if let j = log.firstIndex(where: { $0.id == entryID || $0.id == realID }) {
                        var restored = previous
                        restored.id = realID
                        log[j] = restored
                    }
                    reportSaveError(error)
                }
            }
        } else {
            let tempID = "tmp-\(UUID().uuidString)"
            log.insert(LogEntry(id: tempID, date: draft.date, drink: draft.drink,
                                amount: draft.amount, size: draft.size, notes: draft.notes), at: 0)
            showToast("Logged — cheers!")
            pendingCreates[tempID] = Task {
                defer { pendingCreates[tempID] = nil }
                do {
                    let created = try await api.addLog(payload)
                    if let j = log.firstIndex(where: { $0.id == tempID }) {
                        log[j].id = created.id
                    }
                    refreshCatalogIfNew(draft.drink)
                    return created.id
                } catch {
                    log.removeAll { $0.id == tempID }
                    reportSaveError(error)
                    return nil
                }
            }
        }
        return true
    }

    @discardableResult
    func deleteLog(id: String) async -> Bool {
        guard let api, let i = log.firstIndex(where: { $0.id == id }) else { return false }
        let removed = log.remove(at: i)
        Task {
            guard let realID = await resolveID(id) else { return }
            do {
                try await api.deleteLog(id: realID)
            } catch {
                var restored = removed
                restored.id = realID
                log.insert(restored, at: min(i, log.count))
                reportSaveError(error)
            }
        }
        return true
    }

    @discardableResult
    func saveCatalog(id: Int, payload: DrinkPayload) async -> Bool {
        guard let api, let i = catalog.firstIndex(where: { $0.id == id }) else { return false }
        let previous = catalog[i]
        // payload.image is a raw filename; the server replies with a signed URL for it.
        // Until then keep showing the current photo (or none, if it was removed).
        catalog[i] = Drink(id: id, brewery: payload.brewery, drink: payload.drink, abv: payload.abv,
                           rating: payload.rating, image: payload.image.isEmpty ? "" : previous.image,
                           notes: payload.notes)
        Task {
            do {
                let updated = try await api.updateCatalog(id: id, payload)
                if let j = catalog.firstIndex(where: { $0.id == id }) { catalog[j] = updated }
            } catch {
                if let j = catalog.firstIndex(where: { $0.id == id }) { catalog[j] = previous }
                reportSaveError(error)
            }
        }
        return true
    }

    private func reportSaveError(_ error: Error) {
        let detail = friendly(error)
        errorMessage = "Couldn't save — your change was undone. \(detail)"
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
