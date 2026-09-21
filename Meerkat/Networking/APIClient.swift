import Foundation

// Thin async client for Meerkat's REST API (backend/routes/routes.go).
// Authenticates with a Meerkat API token (Settings → API Tokens) as a Bearer header.

struct APIError: LocalizedError, Equatable {
    var status: Int
    var message: String
    var errorDescription: String? { status == 0 ? message : "\(message) (HTTP \(status))" }

    static let notConfigured = APIError(status: 0, message: "Server URL or API token not set.")
}

actor APIClient {
    static let shared = APIClient()

    private var baseURL: URL?
    private var token: String = ""
    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    func configure(baseURLString: String, token: String) {
        var s = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty, !s.contains("://") { s = "https://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        if s.hasSuffix("/api/v1") { s.removeLast("/api/v1".count) }
        baseURL = URL(string: s)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConfigured: Bool { baseURL != nil && !token.isEmpty }

    // MARK: - Coding

    /// Go emits RFC 3339 with nanosecond precision ("2026-09-21T14:04:46.337202378-04:00");
    /// ISO8601DateFormatter only copes with millisecond fractions, so trim to 3 digits first.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let trimmed = raw.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
            if let date = frac.date(from: trimmed) ?? plain.date(from: trimmed) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(raw)"))
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Core request

    private struct ServerError: Decodable {
        struct Detail: Decodable { var code: String?; var message: String? }
        var error: ErrorBody?
        enum ErrorBody: Decodable {
            case string(String), object(Detail)
            init(from decoder: Decoder) throws {
                let c = try decoder.singleValueContainer()
                if let s = try? c.decode(String.self) { self = .string(s) } else { self = .object(try c.decode(Detail.self)) }
            }
            var text: String {
                switch self {
                case .string(let s): return s
                case .object(let d): return d.message ?? d.code ?? "Request failed"
                }
            }
        }
    }

    @discardableResult
    private func send(_ method: String, _ path: String, query: [String: String] = [:],
                      body: Data? = nil, contentType: String? = "application/json") async throws -> Data {
        try await perform(method, path, query: query, body: body, contentType: contentType).data
    }

    /// Like `send`, but a 404 yields `nil` instead of throwing (used for optional resources).
    private func sendOptional(_ method: String, _ path: String) async throws -> Data? {
        let r = try await perform(method, path, contentType: nil, tolerate404: true)
        return r.status == 404 ? nil : r.data
    }

    private func perform(_ method: String, _ path: String, query: [String: String] = [:],
                         body: Data? = nil, contentType: String? = "application/json",
                         tolerate404: Bool = false) async throws -> (data: Data, status: Int) {
        guard let baseURL, !token.isEmpty else { throw APIError.notConfigured }
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/v1" + path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        req.httpBody = body

        // Meerkat runs on SQLite; under concurrent writes it returns transient 500s
        // (SQLITE_BUSY), so retry those a few times before surfacing an error.
        var lastError = APIError(status: 0, message: "Unknown error")
        for attempt in 0..<4 {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) || (tolerate404 && status == 404) { return (data, status) }
            let msg = (try? Self.decoder.decode(ServerError.self, from: data))?.error?.text
                ?? String(data: data, encoding: .utf8) ?? "Request failed"
            lastError = APIError(status: status, message: msg)
            // "Invalid token" on 401 is how a busy SQLite surfaces during the token lookup.
            let transient = status >= 500 || msg.localizedCaseInsensitiveContains("locked") || msg == "Invalid token"
            if !transient || attempt == 3 { break }
            try await Task.sleep(for: .milliseconds(600 * (attempt + 1)))
        }
        throw lastError
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try Self.decoder.decode(T.self, from: try await send("GET", path, query: query, contentType: nil))
    }

    private func json<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B) async throws -> T {
        let data = try await send(method, path, body: try Self.encoder.encode(body))
        return try Self.decoder.decode(T.self, from: data)
    }

    private func call<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        try await send(method, path, body: try Self.encoder.encode(body))
    }

    private func call(_ method: String, _ path: String) async throws {
        try await send(method, path, contentType: nil)
    }


    // MARK: - Session

    func me() async throws -> User { try await get("/users/me") }

    // MARK: - Contacts

    func contacts(search: String = "", circle: String = "", page: Int = 1, limit: Int = 100,
                  includeArchived: Bool = false, sort: String = "lastname", order: String = "asc") async throws -> ContactPage {
        var q = ["page": String(page), "limit": String(min(limit, 100)), "sort": sort, "order": order]
        if !search.isEmpty { q["search"] = search }
        if !circle.isEmpty { q["circle"] = circle }
        if includeArchived { q["include_archived"] = "true" }
        return try await get("/contacts", query: q)
    }

    func contact(_ id: Int, includes: [String] = ["notes", "activities", "reminders", "relationships"]) async throws -> Contact {
        try await get("/contacts/\(id)", query: includes.isEmpty ? [:] : ["includes": includes.joined(separator: ",")])
    }

    func createContact(_ input: ContactInput) async throws -> Contact {
        let env: ContactEnvelope = try await json("POST", "/contacts", body: input)
        return env.contact
    }

    /// Meerkat's PUT is a full replace; callers should build `input` from a freshly fetched contact.
    func updateContact(_ id: Int, _ input: ContactInput) async throws -> Contact {
        try await json("PUT", "/contacts/\(id)", body: input)
    }

    func deleteContact(_ id: Int) async throws { try await call("DELETE", "/contacts/\(id)") }
    func archiveContact(_ id: Int) async throws { try await call("POST", "/contacts/\(id)/archive") }
    func unarchiveContact(_ id: Int) async throws { try await call("POST", "/contacts/\(id)/unarchive") }

    func circles() async throws -> [String] { try await get("/contacts/circles") }

    func upcomingBirthdays() async throws -> [Birthday] {
        let env: BirthdaysEnvelope = try await get("/contacts/birthdays")
        return env.birthdays ?? []
    }

    // MARK: - Photos

    /// Full-size profile picture; returns nil when the contact has none.
    func photo(for contactId: Int) async throws -> Data? {
        try await sendOptional("GET", "/contacts/\(contactId)/profile_picture")
    }

    func uploadPhoto(for contactId: Int, jpeg: Data) async throws {
        let boundary = "meerkat-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        try await send("POST", "/contacts/\(contactId)/profile_picture", body: body,
                       contentType: "multipart/form-data; boundary=\(boundary)")
    }

    // MARK: - Notes

    func notes(for contactId: Int) async throws -> [Note] {
        let env: NotesEnvelope = try await get("/contacts/\(contactId)/notes")
        return env.notes ?? []
    }

    func addNote(to contactId: Int, content: String, date: Date = .now) async throws {
        try await call("POST", "/contacts/\(contactId)/notes",
                       body: NoteInput(content: content, date: date, contactId: contactId))
    }

    func updateNote(_ id: Int, contactId: Int, content: String, date: Date) async throws {
        try await call("PUT", "/notes/\(id)", body: NoteInput(content: content, date: date, contactId: contactId))
    }

    func deleteNote(_ id: Int) async throws { try await call("DELETE", "/notes/\(id)") }

    // MARK: - Activities

    func activities(for contactId: Int) async throws -> [Activity] {
        let env: ActivitiesEnvelope = try await get("/contacts/\(contactId)/activities")
        return env.activities ?? []
    }

    func addActivity(_ input: ActivityInput) async throws { try await call("POST", "/activities", body: input) }
    func updateActivity(_ id: Int, _ input: ActivityInput) async throws { try await call("PUT", "/activities/\(id)", body: input) }
    func deleteActivity(_ id: Int) async throws { try await call("DELETE", "/activities/\(id)") }

    // MARK: - Reminders

    func reminders(for contactId: Int) async throws -> [Reminder] {
        let env: RemindersEnvelope = try await get("/contacts/\(contactId)/reminders")
        return env.reminders ?? []
    }

    /// Reminders due in the next 7 days, or all open ones when none are due soon.
    func upcomingReminders() async throws -> [Reminder] {
        let env: RemindersEnvelope = try await get("/reminders/upcoming")
        return env.reminders ?? []
    }

    func allReminders() async throws -> [Reminder] {
        let env: RemindersEnvelope = try await get("/reminders")
        return env.reminders ?? []
    }

    func addReminder(_ input: ReminderInput) async throws {
        try await call("POST", "/contacts/\(input.contactId)/reminders", body: input)
    }

    func updateReminder(_ id: Int, _ input: ReminderInput) async throws { try await call("PUT", "/reminders/\(id)", body: input) }
    func completeReminder(_ id: Int) async throws { try await call("POST", "/reminders/\(id)/complete") }
    func deleteReminder(_ id: Int) async throws { try await call("DELETE", "/reminders/\(id)") }

    // MARK: - Relationships

    func relationships(for contactId: Int) async throws -> [Relationship] {
        let env: RelationshipsEnvelope = try await get("/contacts/\(contactId)/relationships")
        return env.relationships ?? []
    }

    func addRelationship(to contactId: Int, _ input: RelationshipInput) async throws {
        try await call("POST", "/contacts/\(contactId)/relationships", body: input)
    }

    func deleteRelationship(contactId: Int, id: Int) async throws {
        try await call("DELETE", "/contacts/\(contactId)/relationships/\(id)")
    }
}
