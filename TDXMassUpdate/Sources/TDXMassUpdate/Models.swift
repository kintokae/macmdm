import Foundation

struct SimpleError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - Identifier

enum IdentifierType: String, CaseIterable, Identifiable {
    case assetID = "Asset ID"
    case serialNumber = "Serial Number"
    case tag = "Asset Tag"

    var id: String { rawValue }

    /// Header written into generated templates.
    var csvHeader: String {
        switch self {
        case .assetID: return "AssetID"
        case .serialNumber: return "SerialNumber"
        case .tag: return "Tag"
        }
    }
}

// MARK: - Asset fields

enum FieldKind: Hashable {
    case string, int, decimal, date, guid
}

struct AssetField: Identifiable, Hashable {
    let header: String          // Name used in the CSV header
    let jsonKey: String         // Property name in the TDX Asset object
    let kind: FieldKind
    var aliases: [String] = []  // Normalized alternate header names
    var id: String { header }
}

enum ColumnTarget: Hashable {
    case identifier
    case field(AssetField)
    case customAttribute(Int)
    case unknown(String)
}

enum AssetFields {
    /// Standard (non custom-attribute) properties of a TDX asset that are safe to mass update.
    static let standard: [AssetField] = [
        AssetField(header: "Name", jsonKey: "Name", kind: .string),
        AssetField(header: "SerialNumber", jsonKey: "SerialNumber", kind: .string, aliases: ["serial"]),
        AssetField(header: "Tag", jsonKey: "Tag", kind: .string, aliases: ["assettag"]),
        AssetField(header: "ExternalID", jsonKey: "ExternalID", kind: .string),
        AssetField(header: "StatusID", jsonKey: "StatusID", kind: .int),
        AssetField(header: "LocationID", jsonKey: "LocationID", kind: .int),
        AssetField(header: "LocationRoomID", jsonKey: "LocationRoomID", kind: .int),
        AssetField(header: "OwningCustomerID", jsonKey: "OwningCustomerID", kind: .guid),
        AssetField(header: "OwningDepartmentID", jsonKey: "OwningDepartmentID", kind: .int),
        AssetField(header: "RequestingCustomerID", jsonKey: "RequestingCustomerID", kind: .guid),
        AssetField(header: "RequestingDepartmentID", jsonKey: "RequestingDepartmentID", kind: .int),
        AssetField(header: "ManufacturerID", jsonKey: "ManufacturerID", kind: .int),
        AssetField(header: "ProductModelID", jsonKey: "ProductModelID", kind: .int),
        AssetField(header: "SupplierID", jsonKey: "SupplierID", kind: .int),
        AssetField(header: "ParentID", jsonKey: "ParentID", kind: .int),
        AssetField(header: "MaintenanceScheduleID", jsonKey: "MaintenanceScheduleID", kind: .int),
        AssetField(header: "PurchaseCost", jsonKey: "PurchaseCost", kind: .decimal),
        AssetField(header: "AcquisitionDate", jsonKey: "AcquisitionDate", kind: .date),
        AssetField(header: "ExpectedReplacementDate", jsonKey: "ExpectedReplacementDate", kind: .date),
    ]

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && $0 != "_" && $0 != "-" }
    }

    /// Maps a CSV header to what it updates. Custom attributes use `Attribute:<ID>` (also `Attr:` or `CA:`).
    static func target(for header: String, isFirst: Bool) -> ColumnTarget {
        if isFirst { return .identifier }
        let trimmed = header.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        for prefix in ["attribute:", "attr:", "ca:"] where lower.hasPrefix(prefix) {
            let rest = lower.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            if let id = Int(rest) { return .customAttribute(id) }
        }
        let n = normalize(trimmed)
        if let f = standard.first(where: { normalize($0.header) == n || $0.aliases.contains(n) }) {
            return .field(f)
        }
        return .unknown(trimmed)
    }
}

// MARK: - Rows

struct CellChange: Hashable {
    let header: String
    let target: ColumnTarget
    let raw: String
}

enum RowStatus: String {
    case pending, invalid, running, skipped, dryRun, success, failed

    var label: String {
        switch self {
        case .pending: return "Ready"
        case .invalid: return "Invalid"
        case .running: return "Working…"
        case .skipped: return "Skipped"
        case .dryRun: return "Preview"
        case .success: return "Updated"
        case .failed: return "Failed"
        }
    }
}

struct UpdateRow: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let identifier: String
    let changes: [CellChange]
    var status: RowStatus = .pending
    var message: String = ""

    var summary: String {
        changes.map { "\($0.header)=\($0.raw)" }.joined(separator: ", ")
    }
}

// MARK: - Issues & log

struct Issue: Identifiable {
    enum Severity { case error, warning, info }
    let id = UUID()
    let severity: Severity
    let text: String
}

struct LogEntry: Identifiable {
    enum Level { case info, success, warning, error }
    let id = UUID()
    let date = Date()
    let level: Level
    let text: String

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    var timestamp: String { Self.formatter.string(from: date) }
}

struct AssetStatus: Identifiable, Hashable {
    let id: Int
    let name: String
}
