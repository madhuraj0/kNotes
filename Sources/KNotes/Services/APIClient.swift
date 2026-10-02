import Foundation

public final class APIClient {
    public static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:8765")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    public func fetchStatus() async throws -> AppStatus {
        let url = baseURL.appendingPathComponent("api/status")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(AppStatus.self, from: data)
    }

    public func login(email: String, password: String? = nil, masterToken: String? = nil) async throws -> (Bool, String) {
        let url = baseURL.appendingPathComponent("api/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["email": email]
        if let password = password, !password.isEmpty {
            body["password"] = password
        }
        if let masterToken = masterToken, !masterToken.isEmpty {
            body["master_token"] = masterToken
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = json?["message"] as? String ?? "Logged in successfully"
            return (true, msg)
        } else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = json?["message"] as? String ?? "Authentication failed"
            return (false, msg)
        }
    }

    public func logout() async throws {
        let url = baseURL.appendingPathComponent("api/auth/logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    public func sync() async throws {
        let url = baseURL.appendingPathComponent("api/sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    public func fetchNotes(folder: String = "all", label: String? = nil, query: String? = nil) async throws -> [Note] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/notes"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "folder", value: folder)
        ]
        if let label = label, !label.isEmpty {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        components.queryItems = queryItems

        guard let url = components.url else { return [] }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([Note].self, from: data)
    }

    public func getNote(id: String) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes/\(id)")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(Note.self, from: data)
    }

    public func createNote(
        title: String,
        text: String = "",
        isList: Bool = false,
        items: [ChecklistItem] = [],
        color: String = "White",
        pinned: Bool = false,
        archived: Bool = false,
        labels: [String] = [],
        collaborators: [String] = []
    ) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "title": title,
            "text": text,
            "is_list": isList,
            "items": items.map { ["id": $0.id as Any, "text": $0.text, "checked": $0.checked] },
            "color": color,
            "pinned": pinned,
            "archived": archived,
            "labels": labels,
            "collaborators": collaborators
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Note.self, from: data)
    }

    public func updateNote(
        id: String,
        title: String? = nil,
        text: String? = nil,
        isList: Bool? = nil,
        items: [ChecklistItem]? = nil,
        color: String? = nil,
        pinned: Bool? = nil,
        archived: Bool? = nil,
        trashed: Bool? = nil,
        labels: [String]? = nil,
        collaborators: [String]? = nil
    ) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let title = title { payload["title"] = title }
        if let text = text { payload["text"] = text }
        if let isList = isList { payload["is_list"] = isList }
        if let items = items {
            payload["items"] = items.map { ["id": $0.id as Any, "text": $0.text, "checked": $0.checked] }
        }
        if let color = color { payload["color"] = color }
        if let pinned = pinned { payload["pinned"] = pinned }
        if let archived = archived { payload["archived"] = archived }
        if let trashed = trashed { payload["trashed"] = trashed }
        if let labels = labels { payload["labels"] = labels }
        if let collaborators = collaborators { payload["collaborators"] = collaborators }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Note.self, from: data)
    }

    public func deleteNote(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/notes/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    public func untrashNote(id: String) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes/\(id)/untrash")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(Note.self, from: data)
    }

    public func fetchLabels() async throws -> [LabelItem] {
        let url = baseURL.appendingPathComponent("api/labels")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([LabelItem].self, from: data)
    }

    public func createLabel(name: String) async throws -> LabelItem {
        let url = baseURL.appendingPathComponent("api/labels")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(LabelItem.self, from: data)
    }

    public func deleteLabel(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/labels/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "KNotesAPIError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(httpResponse.statusCode)"]
            )
        }
    }
}
