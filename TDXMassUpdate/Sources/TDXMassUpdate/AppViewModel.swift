import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: Connection settings (non-secret values persist in UserDefaults, secrets in Keychain)
    @Published var baseURL: String { didSet { defaults.set(baseURL, forKey: "baseURL"); connectionOK = false } }
    @Published var appID: String { didSet { defaults.set(appID, forKey: "appID"); connectionOK = false } }
    @Published var authMode: AuthMode { didSet { defaults.set(authMode.rawValue, forKey: "authMode"); connectionOK = false } }
    @Published var username: String { didSet { defaults.set(username, forKey: "username") } }
    @Published var beid: String { didSet { defaults.set(beid, forKey: "beid") } }
    @Published var password: String
    @Published var webServicesKey: String
    @Published var requestsPerMinute: Int { didSet { defaults.set(requestsPerMinute, forKey: "rpm") } }

    @Published var connectionOK = false
    @Published var connectionMessage = ""
    @Published var isVerifying = false
    @Published var assetStatuses: [AssetStatus] = []

    // MARK: CSV + run state
    @Published var identifierType: IdentifierType {
        didSet {
            defaults.set(identifierType.rawValue, forKey: "identifierType")
            if !isRunning { preflight() }
        }
    }
    @Published var csvFileName: String?
    @Published private(set) var headers: [String] = []
    @Published private(set) var columns: [ColumnTarget] = []
    @Published var rows: [UpdateRow] = []
    @Published var issues: [Issue] = []
    @Published var log: [LogEntry] = []
    @Published var dryRun = true
    @Published var isRunning = false
    @Published var progress: Double = 0
    @Published var processedCount = 0
    @Published var totalToProcess = 0

    private var rawRows: [[String]] = []
    private var runTask: Task<Void, Never>?

    init() {
        baseURL = defaults.string(forKey: "baseURL") ?? ""
        appID = defaults.string(forKey: "appID") ?? ""
        authMode = AuthMode(rawValue: defaults.string(forKey: "authMode") ?? "") ?? .user
        username = defaults.string(forKey: "username") ?? ""
        beid = defaults.string(forKey: "beid") ?? ""
        let rpm = defaults.integer(forKey: "rpm")
        requestsPerMinute = rpm > 0 ? rpm : 60
        identifierType = IdentifierType(rawValue: defaults.string(forKey: "identifierType") ?? "") ?? .serialNumber
        password = Keychain.get("password")
        webServicesKey = Keychain.get("webServicesKey")
    }

    // MARK: Derived

    var isConfigured: Bool {
        guard !baseURL.isEmpty, Int(appID) != nil else { return false }
        switch authMode {
        case .user: return !username.isEmpty && !password.isEmpty
        case .admin: return !beid.isEmpty && !webServicesKey.isEmpty
        }
    }

    var hasBlockingIssues: Bool { issues.contains { $0.severity == .error } }
    var pendingCount: Int { rows.filter { $0.status == .pending }.count }
    var canRun: Bool { !isRunning && isConfigured && !hasBlockingIssues && pendingCount > 0 }

    var statusSummary: String {
        guard !rows.isEmpty else { return "" }
        let counts = Dictionary(grouping: rows, by: \.status).mapValues(\.count)
        let order: [RowStatus] = [.pending, .success, .dryRun, .skipped, .failed, .invalid]
        return order.compactMap { s in counts[s].map { "\($0) \(s.label.lowercased())" } }
            .joined(separator: ", ")
    }

    // MARK: Logging

    func appendLog(_ level: LogEntry.Level, _ text: String) {
        log.append(LogEntry(level: level, text: text))
        if log.count > 5000 { log.removeFirst(log.count - 5000) }
    }

    // MARK: Connection

    private func saveSecrets() {
        Keychain.set(password, for: "password")
        Keychain.set(webServicesKey, for: "webServicesKey")
    }

    func makeConfig() throws -> TDXConfig {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if s.lowercased().hasSuffix("/api") { s.removeLast(4) }
        guard let url = URL(string: s), let scheme = url.scheme, scheme.hasPrefix("http"), url.host != nil else {
            throw SimpleError("Enter the Web API URL, e.g. https://yourorg.teamdynamix.com/TDWebApi")
        }
        guard let app = Int(appID.trimmingCharacters(in: .whitespaces)) else {
            throw SimpleError("Enter the numeric ID of your Assets/CIs application.")
        }
        return TDXConfig(
            baseURL: url, appID: app, authMode: authMode,
            username: username.trimmingCharacters(in: .whitespaces), password: password,
            beid: beid.trimmingCharacters(in: .whitespaces),
            webServicesKey: webServicesKey.trimmingCharacters(in: .whitespaces)
        )
    }

    func verifyConnection() {
        saveSecrets()
        let config: TDXConfig
        do { config = try makeConfig() } catch {
            connectionOK = false
            connectionMessage = error.localizedDescription
            return
        }
        isVerifying = true
        connectionMessage = "Connecting…"
        let rpm = requestsPerMinute
        Task {
            do {
                let client = TDXClient(config: config, requestsPerMinute: rpm)
                try await client.authenticate()
                let statuses = try await client.assetStatuses()
                assetStatuses = statuses
                connectionOK = true
                connectionMessage = "Connected. App \(config.appID) has \(statuses.count) asset statuses."
                appendLog(.success, "Verified connection to \(config.baseURL.absoluteString) (app \(config.appID)).")
            } catch {
                connectionOK = false
                connectionMessage = error.localizedDescription
                appendLog(.error, "Connection check failed: \(error.localizedDescription)")
            }
            isVerifying = false
        }
    }

    // MARK: CSV

    func chooseCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a CSV whose first column identifies each asset."
        if panel.runModal() == .OK, let url = panel.url { loadCSV(from: url) }
    }

    func loadCSV(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw SimpleError("The file isn't readable text.")
            }
            let table = CSVParser.parse(text)
            guard let header = table.first else { throw SimpleError("The CSV is empty.") }
            headers = header.map { $0.trimmingCharacters(in: .whitespaces) }
            columns = headers.enumerated().map { AssetFields.target(for: $1, isFirst: $0 == 0) }
            rawRows = Array(table.dropFirst())
            csvFileName = url.lastPathComponent
            appendLog(.info, "Loaded \(url.lastPathComponent): \(rawRows.count) rows, \(max(0, headers.count - 1)) update columns.")
            preflight()
        } catch {
            appendLog(.error, "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Validates headers and every cell before anything touches TDX, and resets row statuses.
    func preflight() {
        var found: [Issue] = []
        guard !headers.isEmpty else { rows = []; issues = []; return }

        var seen = Set<String>()
        for (i, h) in headers.enumerated() {
            if i > 0, case .unknown = columns[i] {
                found.append(Issue(severity: .error,
                    text: "Column “\(h)” isn't a known asset field. Use a field such as StatusID, or Attribute:<ID> for custom attributes."))
            }
            if !seen.insert(h.lowercased()).inserted {
                found.append(Issue(severity: .error, text: "Column “\(h)” appears more than once."))
            }
        }
        if headers.count < 2 {
            found.append(Issue(severity: .error, text: "Add at least one column to update after the \(identifierType.rawValue) column."))
        }

        var built: [UpdateRow] = []
        var idCounts: [String: Int] = [:]
        for (n, raw) in rawRows.enumerated() {
            let line = n + 2
            let identifier = raw.first?.trimmingCharacters(in: .whitespaces) ?? ""
            var changes: [CellChange] = []
            var problems: [String] = []

            for c in 1..<max(1, columns.count) {
                let value = c < raw.count ? raw[c].trimmingCharacters(in: .whitespaces) : ""
                guard !value.isEmpty else { continue }
                switch columns[c] {
                case .field(let f):
                    do { _ = try AssetUpdater.convert(value, kind: f.kind) } catch {
                        problems.append("\(headers[c]): \(error.localizedDescription)")
                    }
                    changes.append(CellChange(header: headers[c], target: columns[c], raw: value))
                case .customAttribute:
                    changes.append(CellChange(header: headers[c], target: columns[c], raw: value))
                case .identifier, .unknown:
                    break
                }
            }
            if raw.count > columns.count, raw[columns.count...].contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                problems.append("More values than column headers")
            }

            var row = UpdateRow(lineNumber: line, identifier: identifier, changes: changes)
            if identifier.isEmpty {
                row.status = .invalid; row.message = "Missing \(identifierType.rawValue)"
            } else if identifierType == .assetID && Int(identifier) == nil {
                row.status = .invalid; row.message = "Asset ID must be a number"
            } else if !problems.isEmpty {
                row.status = .invalid; row.message = problems.joined(separator: "; ")
            } else if changes.isEmpty {
                row.status = .skipped; row.message = "No values to update"
            }
            if !identifier.isEmpty { idCounts[identifier.lowercased(), default: 0] += 1 }
            built.append(row)
        }

        let dupes = idCounts.filter { $0.value > 1 }.map(\.key)
        if !dupes.isEmpty {
            found.append(Issue(severity: .warning,
                text: "\(dupes.count) identifier(s) appear on more than one row; later rows will overwrite earlier ones."))
        }
        let invalid = built.filter { $0.status == .invalid }.count
        if invalid > 0 {
            found.append(Issue(severity: .warning, text: "\(invalid) row(s) have invalid values and will be skipped. See the Message column."))
        }
        if !built.isEmpty && !found.contains(where: { $0.severity == .error }) {
            let ready = built.filter { $0.status == .pending }.count
            found.append(Issue(severity: .info, text: "Pre-flight passed: \(ready) row(s) ready to process."))
        }

        rows = built
        issues = found
        progress = 0
        processedCount = 0
        totalToProcess = 0
    }

    // MARK: Template

    @discardableResult
    func saveTemplate(columns templateColumns: [String]) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tdx-asset-update-template.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let text = CSVParser.line([identifierType.csvHeader] + templateColumns) + "\n"
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            appendLog(.success, "Saved template to \(url.path).")
            return true
        } catch {
            appendLog(.error, "Couldn't save template: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Run

    func startRun() {
        guard canRun else { return }
        saveSecrets()
        let config: TDXConfig
        do { config = try makeConfig() } catch {
            appendLog(.error, error.localizedDescription)
            return
        }

        let client = TDXClient(config: config, requestsPerMinute: requestsPerMinute)
        let idType = identifierType
        let dry = dryRun
        let targets = rows.indices.filter { rows[$0].status == .pending }

        isRunning = true
        progress = 0
        processedCount = 0
        totalToProcess = targets.count
        appendLog(.info, "Starting \(dry ? "dry run" : "LIVE update") of \(targets.count) asset(s)…")

        runTask = Task {
            var cancelled = false
            for (n, i) in targets.enumerated() {
                if Task.isCancelled { cancelled = true; break }
                rows[i].status = .running
                rows[i].message = ""
                let row = rows[i]
                do {
                    let r = try await client.process(identifier: row.identifier, type: idType,
                                                     changes: row.changes, dryRun: dry)
                    let detail = r.diffs.joined(separator: "; ")
                    if r.diffs.isEmpty {
                        rows[i].status = .skipped
                        rows[i].message = "Asset \(r.assetID) already has these values"
                        appendLog(.info, "Line \(row.lineNumber) (\(row.identifier)): no changes needed.")
                    } else if dry {
                        rows[i].status = .dryRun
                        rows[i].message = "Asset \(r.assetID): \(detail)"
                        appendLog(.info, "Line \(row.lineNumber) (\(row.identifier)) would change: \(detail)")
                    } else {
                        rows[i].status = .success
                        rows[i].message = "Asset \(r.assetID): \(detail)"
                        appendLog(.success, "Line \(row.lineNumber) (\(row.identifier)) updated: \(detail)")
                    }
                } catch {
                    if Task.isCancelled {
                        rows[i].status = .pending
                        rows[i].message = "Cancelled"
                        cancelled = true
                        break
                    }
                    rows[i].status = .failed
                    rows[i].message = error.localizedDescription
                    appendLog(.error, "Line \(row.lineNumber) (\(row.identifier)): \(error.localizedDescription)")
                }
                processedCount = n + 1
                progress = Double(n + 1) / Double(max(1, targets.count))
            }
            isRunning = false
            runTask = nil
            appendLog(cancelled ? .warning : .info,
                      "\(cancelled ? "Cancelled" : "Finished") after \(processedCount) of \(targets.count). \(statusSummary).")
        }
    }

    func cancelRun() {
        runTask?.cancel()
        appendLog(.warning, "Cancelling after the current request…")
    }

    // MARK: Export

    func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let base = (csvFileName as NSString?)?.deletingPathExtension ?? "tdx-update"
        panel.nameFieldStringValue = "\(base)-results.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var out = CSVParser.line(["Line", identifierType.csvHeader, "Status", "Changes", "Message"]) + "\n"
        for r in rows {
            out += CSVParser.line([String(r.lineNumber), r.identifier, r.status.label, r.summary, r.message]) + "\n"
        }
        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
            appendLog(.success, "Exported results to \(url.path).")
        } catch {
            appendLog(.error, "Couldn't export results: \(error.localizedDescription)")
        }
    }
}
