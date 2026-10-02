import Foundation

// MARK: - CSV

enum CSVParser {
    /// RFC 4180-ish parser: quoted fields, escaped quotes (""), embedded commas/newlines, CRLF, BOM.
    static func parse(_ input: String) -> [[String]] {
        let text = input.hasPrefix("\u{FEFF}") ? String(input.dropFirst()) : input
        let chars = Array(text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n", "\r", "\r\n":   // "\r\n" is a single Character in Swift
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                default:
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        // Drop completely blank lines
        return rows.filter { r in r.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func escape(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" || $0 == "\r\n" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func line(_ values: [String]) -> String {
        values.map(escape).joined(separator: ",")
    }
}

// MARK: - Applying CSV values to a TDX asset

enum AssetUpdater {
    /// Like Jamf MUT: blank cells are ignored, this token clears the value.
    static let clearToken = "CLEAR!"

    private static let emptyGuid = "00000000-0000-0000-0000-000000000000"
    private static let minDate = "0001-01-01T00:00:00Z"

    private static let inputDateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd", "M/d/yyyy", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = fmt
            f.isLenient = false
            return f
        }
    }()

    private static let outputDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f
    }()

    /// Converts a CSV cell to the JSON value TDX expects. Throws on invalid input (used by pre-flight too).
    static func convert(_ raw: String, kind: FieldKind) throws -> Any {
        let v = raw.trimmingCharacters(in: .whitespaces)
        if v == clearToken {
            switch kind {
            case .string: return ""
            case .int: return 0
            case .decimal: return 0
            case .date: return minDate
            case .guid: return emptyGuid
            }
        }
        switch kind {
        case .string:
            return v
        case .int:
            guard let i = Int(v), i >= 0 else { throw SimpleError("“\(v)” is not a valid ID number") }
            return i
        case .decimal:
            let cleaned = v.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            guard let d = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
                throw SimpleError("“\(v)” is not a number")
            }
            return NSDecimalNumber(decimal: d)
        case .date:
            for f in inputDateFormatters {
                if let date = f.date(from: v) { return outputDateFormatter.string(from: date) }
            }
            throw SimpleError("“\(v)” is not a date (use YYYY-MM-DD or M/D/YYYY)")
        case .guid:
            guard UUID(uuidString: v) != nil else { throw SimpleError("“\(v)” is not a valid person UID (GUID)") }
            return v.lowercased()
        }
    }

    static func describe(_ value: Any?) -> String {
        guard let value else { return "(empty)" }
        switch value {
        case is NSNull: return "(empty)"
        case let s as String: return s.isEmpty ? "(empty)" : s
        case let n as NSNumber: return n.stringValue
        default: return "\(value)"
        }
    }

    private static func matches(_ old: Any?, _ new: Any, kind: FieldKind) -> Bool {
        let o = describe(old), n = describe(new)
        switch kind {
        case .date:
            return o.prefix(10) == n.prefix(10)
        case .guid, .string:
            return o.caseInsensitiveCompare(n) == .orderedSame && (kind == .guid || o == n)
        case .decimal:
            return Decimal(string: o) == Decimal(string: n)
        case .int:
            return o == n || (o == "(empty)" && n == "0")
        }
    }

    /// Mutates the asset dictionary in place. Returns human-readable diffs; empty means nothing changed.
    static func apply(_ changes: [CellChange], to asset: inout [String: Any]) throws -> [String] {
        var diffs: [String] = []
        var attributes = (asset["Attributes"] as? [[String: Any]]) ?? []
        var attributesChanged = false

        for change in changes {
            switch change.target {
            case .field(let field):
                let newValue = try convert(change.raw, kind: field.kind)
                let old = asset[field.jsonKey]
                if !matches(old, newValue, kind: field.kind) {
                    asset[field.jsonKey] = newValue
                    diffs.append("\(field.header): \(describe(old)) → \(describe(newValue))")
                }

            case .customAttribute(let attrID):
                let idx = attributes.firstIndex { ($0["ID"] as? Int) == attrID }
                let old = idx.map { describe(attributes[$0]["Value"]) } ?? "(empty)"
                let value = change.raw.trimmingCharacters(in: .whitespaces)
                if value == clearToken {
                    if let idx {
                        attributes.remove(at: idx)
                        attributesChanged = true
                        diffs.append("Attribute \(attrID): \(old) → (cleared)")
                    }
                } else if old != value {
                    if let idx {
                        attributes[idx]["Value"] = value
                    } else {
                        attributes.append(["ID": attrID, "Value": value])
                    }
                    attributesChanged = true
                    diffs.append("Attribute \(attrID): \(old) → \(value)")
                }

            case .identifier, .unknown:
                break
            }
        }

        if attributesChanged || !diffs.isEmpty {
            // Send back only ID/Value pairs. TDX replaces the asset's attribute set on edit,
            // so every existing attribute must be included to be preserved.
            asset["Attributes"] = attributes.compactMap { a -> [String: Any]? in
                guard let id = a["ID"] else { return nil }
                return ["ID": id, "Value": a["Value"] ?? ""]
            }
        }
        return diffs
    }
}
