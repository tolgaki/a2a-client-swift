// AnyCodable.swift
// A2AClient
//
// Type-erased Codable wrapper for dynamic JSON values

import Foundation

/// A type-erased Codable value that can represent any JSON-compatible value.
///
/// This is used for metadata, extensions, and other dynamic data structures
/// in the A2A protocol where the schema is not fixed.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    /// The underlying value.
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode AnyCodable"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        case (let l as [Any], let r as [Any]):
            return l.count == r.count && zip(l, r).allSatisfy { AnyCodable($0.0) == AnyCodable($0.1) }
        case (let l as [String: Any], let r as [String: Any]):
            return l.count == r.count && l.keys.allSatisfy { key in
                guard let lValue = l[key], let rValue = r[key] else { return false }
                return AnyCodable(lValue) == AnyCodable(rValue)
            }
        default:
            return false
        }
    }
}

// MARK: - Convenience Extensions

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.value = NSNull()
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.value = elements
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.value = Dictionary(uniqueKeysWithValues: elements)
    }
}

// MARK: - Value Accessors

extension AnyCodable {
    /// Returns the value as a String, if possible.
    public var stringValue: String? {
        value as? String
    }

    /// Returns the value as an Int, if possible.
    public var intValue: Int? {
        value as? Int
    }

    /// Returns the value as a Double, if possible.
    public var doubleValue: Double? {
        value as? Double
    }

    /// Returns the value as a Bool, if possible.
    public var boolValue: Bool? {
        value as? Bool
    }

    /// Returns the value as an Array, if possible.
    public var arrayValue: [Any]? {
        value as? [Any]
    }

    /// Returns the value as a Dictionary, if possible.
    public var dictionaryValue: [String: Any]? {
        value as? [String: Any]
    }

    /// Returns whether the value is null.
    public var isNull: Bool {
        value is NSNull
    }
}
