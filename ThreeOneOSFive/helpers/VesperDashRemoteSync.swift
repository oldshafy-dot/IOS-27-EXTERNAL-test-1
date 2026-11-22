enum VesperStringVault {
    // MONITE dashboard API. The license verification API remains separate
    // and is handled by LicenseManager.swift.
    static let moniteBaseURL = "https://shafaydeveloperadmin.lovable.app"
    static let m3sbAPIBaseURL = "https://api.shafay.site"
    static let m3sbVerifyPath = "/api/v1/verify"
    static let vesperDashClientSessionURL = moniteBaseURL + "/api/public"
    static let vesperDashPatchesURL = moniteBaseURL + "/api/public/patches?bundle_id=monite.external"
    static let vesperDashSettingsURL = moniteBaseURL + "/api/public/notices?bundle_id=monite.external"
    static let moniteMaintenanceURL = moniteBaseURL + "/api/public/maintenance?bundle_id=monite.external"
    static let moniteNoticesURL = moniteBaseURL + "/api/public/notices?bundle_id=monite.external"
    static let moniteGamesURL = moniteBaseURL + "/api/public/patches?bundle_id=monite.external"
    static let moniteFunctionsURL = moniteBaseURL + "/api/public/patches?bundle_id=monite.external"
    static let moniteCategoriesURL = moniteBaseURL + "/api/public/patches?bundle_id=monite.external"
    static let moniteUpdatesURL = moniteBaseURL + "/api/public/updates?bundle_id=monite.external"
    static let vesperChannelURL = "https://t.me/roboios"
    static let nullzthURL = ""
    static let nullzthChannelURL = ""
    static let tiktokURL = ""
    static let telegramBaseURL = "https://t.me/"
}
import Foundation

struct VesperDashManifest: Decodable {
    let version: Int
    let global_paused: Bool
    let patches: [RemotePatch]
    let all_patches: [RemotePatch]?
    let package_passwords: [String]?
}

struct VesperReleasePolicy: Decodable {
    let latestBuild: Int
    let minimumBuild: Int
    let downloadURL: URL
    let updateMessage: String

    private enum CodingKeys: String, CodingKey {
        case latestBuild = "latest_build"
        case minimumBuild = "minimum_build"
        case downloadURL = "download_url"
        case updateMessage = "update_message"
    }

    var displayUpdateMessage: String {
        let value = updateMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "IPA UPDATED, PLEASE DOWNLOAD NEW VERSION" : String(value.prefix(240))
    }
}

struct RemotePatch: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: String?
    let game: String
    let bundle_id: String
    let target_path: String
    let target_paths: [String]?
    let filename: String
    let sha256: String
    let version: String
    let download_url: String
    let image_url: String?
    let status_text: String?
    let sort_order: Int?
    let enabled: Bool
    let paused: Bool

    var normalizedCategory: String {
        let value = (category ?? "aim").lowercased()
        if value == "hologram" { return "weapons" }
        return ["aim", "esp", "body", "weapons", "skin"].contains(value) ? value : "aim"
    }

    var normalizedStatus: String {
        let value = status_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "NO STATUS" : String(value.prefix(180))
    }

    var displayStatusText: String {
        let value = status_text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(value.prefix(180))
    }

    var normalizedOrder: Int {
        sort_order ?? 1000
    }

    var normalizedTargetPaths: [String] {
        let values = (target_paths ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return values.isEmpty ? [target_path] : values
    }
}

struct ManifestHTTPError: LocalizedError {
    let statusCode: Int
    var errorDescription: String? { "API returned HTTP \(statusCode)" }
}

enum VesperDashRemoteSync {
    static let manifestURL = URL(string: VesperStringVault.vesperDashPatchesURL)!

    static func fetchReleasePolicy() async throws -> VesperReleasePolicy {
        var components = URLComponents(url: manifestURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/public/updates"
        components.queryItems = [URLQueryItem(name: "bundle_id", value: "monite.external")]
        components.fragment = nil
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let policy = try JSONDecoder().decode(VesperReleasePolicy.self, from: data)
        guard policy.latestBuild >= 1,
              policy.minimumBuild >= 0,
              policy.minimumBuild <= policy.latestBuild,
              policy.downloadURL.scheme?.lowercased() == "https",
              policy.downloadURL.user == nil,
              policy.downloadURL.password == nil else {
            throw URLError(.cannotParseResponse)
        }
        return policy
    }

    static func downloadPackageFile(
        for remote: RemotePatch,
        sessionToken: String,
        using session: URLSession,
        into directory: URL
    ) async throws -> URL {
        guard let url = validDownloadURL(for: remote) else {
            throw PatchPackageError.remoteImportFailed
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 180
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        let (temporaryURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PatchPackageError.remoteImportFailed
        }
        let destination = directory.appendingPathComponent("\(UUID().uuidString).download")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func fetchManifest(sessionToken: String) async throws -> VesperDashManifest {
        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if (400..<500).contains(http.statusCode) && http.statusCode != 408 && http.statusCode != 429 {
                throw ManifestHTTPError(statusCode: http.statusCode)
            }
            throw URLError(.badServerResponse)
        }
        if let manifest = try? JSONDecoder().decode(VesperDashManifest.self, from: data) {
            return manifest
        }
        if let array = try? JSONDecoder().decode([RemotePatch].self, from: data) {
            return VesperDashManifest(
                version: 1,
                global_paused: false,
                patches: array.filter { $0.enabled && !$0.paused },
                all_patches: array,
                package_passwords: nil
            )
        }
        if let wrapper = try? JSONDecoder().decode(MonitePatchWrapper.self, from: data) {
            return VesperDashManifest(
                version: wrapper.version ?? 1,
                global_paused: wrapper.global_paused ?? false,
                patches: wrapper.patches.filter { $0.enabled && !$0.paused },
                all_patches: wrapper.patches,
                package_passwords: wrapper.package_passwords
            )
        }
        throw URLError(.cannotParseResponse)
    }

    static func validDownloadURL(for patch: RemotePatch) -> URL? {
        guard let url = URL(string: patch.download_url, relativeTo: manifestURL)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              patch.bundle_id == "com.dts.freefireth" || patch.bundle_id == "com.dts.freefiremax",
              patch.filename.lowercased().hasSuffix(".3105") else { return nil }
        return url
    }

    static func validImageURL(for patch: RemotePatch) -> URL? {
        guard let value = patch.image_url,
              let url = URL(string: value, relativeTo: manifestURL)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "api.shafay.site",
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}


struct VesperAppSettings: Decodable {
    private enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case developerName = "developer_name"
        case developerSubtitle = "developer_subtitle"
        case channelName = "channel_name"
        case channelHandle = "channel_handle"
        case channelURL = "channel_url"
        case ownerName = "owner_name"
        case ownerHandle = "owner_handle"
        case ownerURL = "owner_url"
        case footerText = "footer_text"
    }

    let appName: String
    let developerName: String
    let developerSubtitle: String
    let channelName: String
    let channelHandle: String
    let channelURL: String
    let ownerName: String
    let ownerHandle: String
    let ownerURL: String
    let footerText: String

    static let fallback = VesperAppSettings(
        appName: "ROBO iOS",
        developerName: "Yagami",
        developerSubtitle: "ROBO iOS Developer",
        channelName: "SAKK EXTERNAL Discord Server",
        channelHandle: "Discord",
        channelURL: "https://discord.gg/VqkjH4pJv",
        ownerName: "ROBO iOS Owner",
        ownerHandle: "@Rybkx",
        ownerURL: "https://discord.gg/VqkjH4pJv",
        footerText: "ROBO iOS • READY"
    )

    init(appName: String, developerName: String, developerSubtitle: String, channelName: String, channelHandle: String, channelURL: String, ownerName: String, ownerHandle: String, ownerURL: String, footerText: String) {
        self.appName = appName; self.developerName = developerName; self.developerSubtitle = developerSubtitle
        self.channelName = channelName; self.channelHandle = channelHandle; self.channelURL = channelURL
        self.ownerName = ownerName; self.ownerHandle = ownerHandle; self.ownerURL = ownerURL; self.footerText = footerText
    }

    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        let f = VesperAppSettings.fallback
        func currentValue(_ key: CodingKeys, fallback: String) throws -> String {
            let value = try d.decodeIfPresent(String.self, forKey: key) ?? fallback
            return value.lowercased().contains("vesper") ? fallback : value
        }
        appName = try currentValue(.appName, fallback: f.appName)
        developerName = try currentValue(.developerName, fallback: f.developerName)
        developerSubtitle = try currentValue(.developerSubtitle, fallback: f.developerSubtitle)
        channelName = try currentValue(.channelName, fallback: f.channelName)
        channelHandle = try currentValue(.channelHandle, fallback: f.channelHandle)
        channelURL = try currentValue(.channelURL, fallback: f.channelURL)
        ownerName = try currentValue(.ownerName, fallback: f.ownerName)
        ownerHandle = try currentValue(.ownerHandle, fallback: f.ownerHandle)
        ownerURL = try currentValue(.ownerURL, fallback: f.ownerURL)
        footerText = try currentValue(.footerText, fallback: f.footerText)
    }
}

extension VesperDashRemoteSync {
    static let settingsURL = URL(string: VesperStringVault.vesperDashSettingsURL)!

    static func fetchAppSettings() async throws -> VesperAppSettings {
        let (data, response) = try await URLSession.shared.data(from: settingsURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(VesperAppSettings.self, from: data)
    }
}


private struct MonitePatchWrapper: Decodable {
    let version: Int?
    let global_paused: Bool?
    let patches: [RemotePatch]
    let package_passwords: [String]?
}


// MARK: - MONITE Dashboard API
import Foundation
import CoreFoundation

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
