import Foundation\nimport CoreFoundation

/// Central MONITE dashboard client.
/// The Base44 app API key is intentionally NOT embedded in the iOS client.
/// Public/read-only app endpoints are called directly; license verification
/// remains in LicenseManager and uses its separate verification service.
final class MoniteAPIClient {
    static let shared = MoniteAPIClient()
    private init() {}

    struct Snapshot: Sendable {
        let maintenance: JSONValue?
        let config: JSONValue?
        let notices: JSONValue?
        let games: JSONValue?
        let functions: JSONValue?
        let categories: JSONValue?
        let patches: JSONValue?
        let updates: JSONValue?
    }

    enum APIError: LocalizedError {
        case badURL
        case invalidResponse(Int)
        case invalidJSON
        case emptyResponse(String)

        var errorDescription: String? {
            switch self {
            case .badURL: return "MONITE API URL is invalid"
            case .invalidResponse(let code): return "MONITE API returned HTTP \(code)"
            case .invalidJSON: return "MONITE API returned invalid JSON"
            case .emptyResponse(let path): return "MONITE API returned no data for \(path)"
            }
        }
    }

    func loadSnapshot(sessionToken: String?) async -> Snapshot {
        async let maintenance = optionalGet(path: "/api/v1/maintenance", sessionToken: sessionToken)
        async let config = optionalGet(path: "/api/v1/config", sessionToken: sessionToken)
        async let notices = optionalGet(path: "/api/v1/notices", sessionToken: sessionToken)
        async let games = optionalGet(path: "/api/v1/games", sessionToken: sessionToken)
        async let functions = optionalGet(path: "/api/v1/functions", sessionToken: sessionToken)
        async let categories = optionalGet(path: "/api/v1/categories", sessionToken: sessionToken)
        async let patches = optionalGet(path: "/api/v1/patches", sessionToken: sessionToken)
        async let updates = optionalGet(path: "/api/v1/updates", sessionToken: sessionToken)

        return await Snapshot(
            maintenance: maintenance,
            config: config,
            notices: notices,
            games: games,
            functions: functions,
            categories: categories,
            patches: patches,
            updates: updates
        )
    }

    private func optionalGet(path: String, sessionToken: String?) async -> JSONValue? {
        try? await get(path: path, sessionToken: sessionToken)
    }

    func get(path: String, sessionToken: String? = nil) async throws -> JSONValue {
        guard let url = URL(string: VesperStringVault.moniteBaseURL + path) else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let sessionToken, !sessionToken.isEmpty {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse(http.statusCode)
        }
        guard !data.isEmpty else {
            throw APIError.emptyResponse(path)
        }
        guard let value = try? JSONValue(data: data) else {
            throw APIError.invalidJSON
        }
        return value
    }
}

enum JSONValue: Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        self = try JSONValue(object: object)
    }

    private init(object: Any) throws {
        switch object {
        case let value as [String: Any]:
            var result: [String: JSONValue] = [:]
            for (key, item) in value {
                result[key] = try JSONValue(object: item)
            }
            self = .object(result)
        case let value as [Any]:
            self = .array(try value.map { try JSONValue(object: $0) })
        case let value as String:
            self = .string(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case _ as NSNull:
            self = .null
        default:
            throw MoniteAPIClient.APIError.invalidJSON
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}
