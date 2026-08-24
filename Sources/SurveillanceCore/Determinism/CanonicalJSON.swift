import Foundation

/// Canonical JSON: UTF-8, sorted object keys, no insignificant whitespace, decimal integers only.
public enum CanonicalJSON: Equatable, Sendable {
    case object([String: CanonicalJSON])
    case array([CanonicalJSON])
    case string(String)
    case integer(Int64)
    case unsigned(UInt64)
    case bool(Bool)
    case null

    public func serialize() -> String {
        var output = ""
        write(to: &output)
        return output
    }

    public func sha256Hex() -> String {
        SHA256.hex(serialize())
    }

    public static func parse(_ value: Any) -> CanonicalJSON? {
        switch value {
        case is NSNull:
            return .null
        case let value as Bool:
            return .bool(value)
        case let value as String:
            return .string(value)
        case let value as [Any]:
            var items: [CanonicalJSON] = []
            items.reserveCapacity(value.count)
            for item in value {
                guard let parsed = parse(item) else { return nil }
                items.append(parsed)
            }
            return .array(items)
        case let value as [String: Any]:
            var fields: [String: CanonicalJSON] = [:]
            for (key, item) in value {
                guard let parsed = parse(item) else { return nil }
                fields[key] = parsed
            }
            return .object(fields)
        case let value as Int:
            return .integer(Int64(value))
        case let value as Int64:
            return .integer(value)
        case let value as UInt64:
            return .unsigned(value)
        case let value as NSNumber:
            return .integer(value.int64Value)
        default:
            return nil
        }
    }

    private func write(to output: inout String) {
        switch self {
        case .null:
            output += "null"
        case .bool(let value):
            output += value ? "true" : "false"
        case .integer(let value):
            output += String(value)
        case .unsigned(let value):
            output += String(value)
        case .string(let value):
            output += "\""
            for scalar in value.unicodeScalars {
                switch scalar.value {
                case 0x22: output += "\\\""
                case 0x5c: output += "\\\\"
                case 0x08: output += "\\b"
                case 0x0c: output += "\\f"
                case 0x0a: output += "\\n"
                case 0x0d: output += "\\r"
                case 0x09: output += "\\t"
                case 0x00..<0x20:
                    output += String(format: "\\u%04x", scalar.value)
                default:
                    output.unicodeScalars.append(scalar)
                }
            }
            output += "\""
        case .array(let items):
            output += "["
            for (index, item) in items.enumerated() {
                if index > 0 { output += "," }
                item.write(to: &output)
            }
            output += "]"
        case .object(let fields):
            output += "{"
            for (index, key) in fields.keys.sorted().enumerated() {
                if index > 0 { output += "," }
                CanonicalJSON.string(key).write(to: &output)
                output += ":"
                fields[key]!.write(to: &output)
            }
            output += "}"
        }
    }
}
