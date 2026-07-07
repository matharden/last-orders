import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? {
        message.isEmpty ? "Request failed (HTTP \(status))" : message
    }
}

/// Thin client for the Go backend. Auth matches the server's model: it only
/// checks for a non-empty `auth_session` cookie, whose value is the user's email.
struct APIClient {
    let baseURL: URL
    let email: String

    private func makeRequest(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: baseURL.appending(path: path))
        req.httpMethod = method
        req.httpShouldHandleCookies = false
        req.setValue("auth_session=\(email)", forHTTPHeaderField: "Cookie")
        return req
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError(status: 0, message: "No response from server")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw APIError(status: http.statusCode, message: body)
        }
        return data
    }

    private func decodeList<T: Decodable>(_ data: Data) throws -> [T] {
        // The Go server encodes empty slices as `null`.
        let trimmed = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == nil || trimmed == "null" || trimmed!.isEmpty { return [] }
        return try JSONDecoder().decode([T].self, from: data)
    }

    private func sendJSON(_ path: String, method: String, body: some Encodable) async throws -> Data {
        var req = makeRequest(path, method: method)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    // MARK: - Endpoints

    func fetchCatalog() async throws -> [Drink] {
        try decodeList(await send(makeRequest("api/catalog")))
    }

    func fetchLog() async throws -> [LogEntry] {
        try decodeList(await send(makeRequest("api/log")))
    }

    func addLog(_ payload: LogPayload) async throws -> LogEntry {
        let data = try await sendJSON("api/log", method: "POST", body: payload)
        return try JSONDecoder().decode(LogEntry.self, from: data)
    }

    func updateLog(id: String, _ payload: LogPayload) async throws {
        _ = try await sendJSON("api/log/\(id)", method: "PUT", body: payload)
    }

    func deleteLog(id: String) async throws {
        _ = try await send(makeRequest("api/log/\(id)", method: "DELETE"))
    }

    func updateCatalog(id: Int, _ payload: DrinkPayload) async throws -> Drink {
        let data = try await sendJSON("api/catalog/\(id)", method: "PUT", body: payload)
        return try JSONDecoder().decode(Drink.self, from: data)
    }

    func deleteCatalog(id: Int) async throws {
        _ = try await send(makeRequest("api/catalog/\(id)", method: "DELETE"))
    }

    /// Uploads an image and returns the stored filename (the raw name kept in the sheet).
    func upload(imageData: Data, filename: String, mimeType: String = "image/jpeg") async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = makeRequest("api/upload", method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let data = try await send(req)
        struct UploadResponse: Decodable { let filename: String }
        return try JSONDecoder().decode(UploadResponse.self, from: data).filename
    }
}

private extension Data {
    mutating func appendString(_ s: String) {
        append(Data(s.utf8))
    }
}
