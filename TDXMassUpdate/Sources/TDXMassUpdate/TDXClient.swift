import Foundation

enum AuthMode: String, CaseIterable, Identifiable {
    case user = "Username & Password"
    case admin = "BEID & Web Services Key"
    var id: String { rawValue }
}

struct TDXConfig {
    var baseURL: URL          // e.g. https://yourorg.teamdynamix.com/TDWebApi  (or /SBTDWebApi for sandbox)
    var appID: Int            // Asset/CI application ID
    var authMode: AuthMode
    var username = ""
    var password = ""
    var beid = ""
    var webServicesKey = ""
}

enum TDXError: LocalizedError {
    case authFailed(Int, String)
    case http(Int, String)
    case notFound(String)
    case ambiguous(String, Int)
    case invalidIdentifier(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .authFailed(let code, let msg): return "Sign-in failed (HTTP \(code)). \(msg)"
        case .http(let code, let msg): return "TDX returned HTTP \(code). \(msg)"
        case .notFound(let id): return "No asset matches “\(id)”."
        case .ambiguous(let id, let n): return "\(n) assets match “\(id)”. Use Asset ID for this row."
        case .invalidIdentifier(let id): return "“\(id)” is not a numeric Asset ID."
        case .unexpectedResponse: return "TDX sent a response this app couldn't read."
        }
    }
}

struct ProcessResult {
    let assetID: Int
    let diffs: [String]
    let saved: Bool
}

actor TDXClient {
    private let config: TDXConfig
    private let session: URLSession
    private let minInterval: TimeInterval
    private var token: String?
    private var lastRequest = Date.distantPast

    init(config: TDXConfig, requestsPerMinute: Int) {
        self.config = config
        self.session = URLSession(configuration: .ephemeral)
        self.minInterval = 60.0 / Double(max(1, requestsPerMinute))
    }

    // MARK: Auth

    func authenticate() async throws {
        let path: String
        let body: [String: String]
        switch config.authMode {
        case .user:
            path = "api/auth/login"
            body = ["UserName": config.username, "Password": config.password]
        case .admin:
            path = "api/auth/loginadmin"
            body = ["BEID": config.beid, "WebServicesKey": config.webServicesKey]
        }
        var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        await throttle()
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw TDXError.unexpectedResponse }
        guard http.statusCode == 200 else {
            throw TDXError.authFailed(http.statusCode, Self.errorMessage(from: data))
        }
        // The login endpoint returns the bearer token as plain text.
        let raw = String(decoding: data, as: UTF8.self)
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
        guard !t.isEmpty else { throw TDXError.unexpectedResponse }
        token = t
    }

    // MARK: Requests

    private func throttle() async {
        let wait = minInterval - Date().timeIntervalSince(lastRequest)
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        lastRequest = Date()
    }

    private func send(_ method: String, _ path: String, body: Any? = nil) async throws -> Any? {
        if token == nil { try await authenticate() }
        var attempt = 0
        while true {
            attempt += 1
            try Task.checkCancellation()

            var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
            req.httpMethod = method
            req.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body {
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }

            await throttle()
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw TDXError.unexpectedResponse }

            switch http.statusCode {
            case 200..<300:
                if data.isEmpty { return nil }
                return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            case 401 where attempt <= 2:
                try await authenticate()       // token expired (they last ~24h)
            case 429 where attempt <= 8:
                let delay = Self.retryDelay(http)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            default:
                throw TDXError.http(http.statusCode, Self.errorMessage(from: data))
            }
        }
    }

    private static func retryDelay(_ http: HTTPURLResponse) -> TimeInterval {
        if let s = http.value(forHTTPHeaderField: "Retry-After"), let secs = Double(s) {
            return min(max(secs, 1), 120)
        }
        if let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset") {
            if let secs = Double(reset) { return min(max(secs, 1), 120) }
            let rfc = DateFormatter()
            rfc.locale = Locale(identifier: "en_US_POSIX")
            rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            let date = ISO8601DateFormatter().date(from: reset) ?? rfc.date(from: reset)
            if let date { return min(max(date.timeIntervalSinceNow + 1, 1), 120) }
        }
        return 15
    }

    private static func errorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = obj["Message"] as? String ?? obj["message"] as? String {
            return msg
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(300))
    }

    // MARK: Assets

    func assetStatuses() async throws -> [AssetStatus] {
        guard let list = try await send("GET", "api/\(config.appID)/assets/statuses") as? [[String: Any]] else {
            throw TDXError.unexpectedResponse
        }
        return list.compactMap { s in
            guard let id = s["ID"] as? Int else { return nil }
            return AssetStatus(id: id, name: s["Name"] as? String ?? "")
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func search(_ criteria: [String: Any]) async throws -> [[String: Any]] {
        guard let list = try await send("POST", "api/\(config.appID)/assets/search", body: criteria) as? [[String: Any]] else {
            throw TDXError.unexpectedResponse
        }
        return list
    }

    func findAssetID(_ identifier: String, type: IdentifierType) async throws -> Int {
        let value = identifier.trimmingCharacters(in: .whitespaces)
        let matches: [[String: Any]]
        switch type {
        case .assetID:
            guard let id = Int(value) else { throw TDXError.invalidIdentifier(value) }
            return id
        case .serialNumber:
            let results = try await search(["SerialLike": value, "MaxResults": 25])
            matches = results.filter {
                ($0["SerialNumber"] as? String)?.caseInsensitiveCompare(value) == .orderedSame
            }
        case .tag:
            let results = try await search(["SearchText": value, "MaxResults": 50])
            matches = results.filter {
                ($0["Tag"] as? String)?.caseInsensitiveCompare(value) == .orderedSame
            }
        }
        guard !matches.isEmpty else { throw TDXError.notFound(value) }
        guard matches.count == 1 else { throw TDXError.ambiguous(value, matches.count) }
        guard let id = matches[0]["ID"] as? Int else { throw TDXError.unexpectedResponse }
        return id
    }

    private func getAsset(_ id: Int) async throws -> [String: Any] {
        guard let asset = try await send("GET", "api/\(config.appID)/assets/\(id)") as? [String: Any] else {
            throw TDXError.unexpectedResponse
        }
        return asset
    }

    private func saveAsset(_ id: Int, _ asset: [String: Any]) async throws {
        // POST api/{appId}/assets/{id} edits the asset; the full object is sent back.
        _ = try await send("POST", "api/\(config.appID)/assets/\(id)", body: asset)
    }

    /// Look up → fetch → apply CSV values → save (unless dry run). Everything stays inside the actor.
    func process(identifier: String, type: IdentifierType, changes: [CellChange], dryRun: Bool) async throws -> ProcessResult {
        let id = try await findAssetID(identifier, type: type)
        var asset = try await getAsset(id)
        let diffs = try AssetUpdater.apply(changes, to: &asset)
        if diffs.isEmpty || dryRun {
            return ProcessResult(assetID: id, diffs: diffs, saved: false)
        }
        try await saveAsset(id, asset)
        return ProcessResult(assetID: id, diffs: diffs, saved: true)
    }
}
