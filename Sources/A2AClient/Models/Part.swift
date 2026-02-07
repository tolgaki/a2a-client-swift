// Part.swift
// A2AClient
//
// Agent2Agent Protocol - Content Part Definitions
// Spec: https://a2a-protocol.org/latest/specification/#416-part

import Foundation

/// Represents a content part within a Message or Artifact.
///
/// Parts are the smallest unit of content in the A2A protocol.
/// Each Part contains exactly one of: text, raw bytes, URL reference, or structured data.
///
/// Per the A2A spec, a Part MUST contain exactly one content field.
public struct Part: Codable, Sendable, Equatable {
    // MARK: - Content (oneof - exactly one must be set)

    /// Plain text content.
    public let text: String?

    /// Raw byte content (base64-encoded in JSON serialization).
    public let raw: Data?

    /// URL pointing to the content.
    public let url: String?

    /// Arbitrary structured data as a JSON value.
    public let data: AnyCodable?

    // MARK: - Common Fields

    /// Optional metadata associated with this part.
    public let metadata: [String: AnyCodable]?

    /// Optional filename (e.g., "document.pdf").
    public let filename: String?

    /// Media type (MIME type) of the content (e.g., "text/plain", "image/png").
    public let mediaType: String?

    // MARK: - Initialization

    public init(
        text: String? = nil,
        raw: Data? = nil,
        url: String? = nil,
        data: AnyCodable? = nil,
        metadata: [String: AnyCodable]? = nil,
        filename: String? = nil,
        mediaType: String? = nil
    ) {
        let contentFieldCount = [text != nil, raw != nil, url != nil, data != nil].filter { $0 }.count
        precondition(contentFieldCount == 1, "Part must contain exactly one content field (text, raw, url, or data), found \(contentFieldCount)")
        self.text = text
        self.raw = raw
        self.url = url
        self.data = data
        self.metadata = metadata
        self.filename = filename
        self.mediaType = mediaType
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case text
        case raw
        case url
        case data
        case metadata
        case filename
        case mediaType = "media_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode content fields
        self.text = try container.decodeIfPresent(String.self, forKey: .text)

        // Raw is base64-encoded in JSON - validate base64 encoding
        if let base64String = try container.decodeIfPresent(String.self, forKey: .raw) {
            guard let decodedData = Data(base64Encoded: base64String) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .raw,
                    in: container,
                    debugDescription: "Invalid base64 encoding for 'raw' field"
                )
            }
            self.raw = decodedData
        } else {
            self.raw = nil
        }

        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.data = try container.decodeIfPresent(AnyCodable.self, forKey: .data)

        // Decode common fields
        self.metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.filename = try container.decodeIfPresent(String.self, forKey: .filename)
        self.mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)

        // Validate exactly one content field is set per A2A spec
        let contentFieldCount = [
            self.text != nil,
            self.raw != nil,
            self.url != nil,
            self.data != nil
        ].filter { $0 }.count

        guard contentFieldCount == 1 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Part must contain exactly one content field (text, raw, url, or data), found \(contentFieldCount)"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode content fields (only one should be set)
        try container.encodeIfPresent(text, forKey: .text)

        // Raw is base64-encoded in JSON
        if let raw = raw {
            try container.encode(raw.base64EncodedString(), forKey: .raw)
        }

        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(data, forKey: .data)

        // Encode common fields
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
    }
}

// MARK: - Content Type Detection

extension Part {
    /// The type of content in this part.
    public enum ContentType: String, Sendable {
        case text
        case raw
        case url
        case data
        case unknown
    }

    /// Returns the content type of this part.
    public var contentType: ContentType {
        if text != nil { return .text }
        if raw != nil { return .raw }
        if url != nil { return .url }
        if data != nil { return .data }
        return .unknown
    }

    /// Whether this part has valid content (exactly one content field set).
    public var isValid: Bool {
        let contentCount = [text != nil, raw != nil, url != nil, data != nil].filter { $0 }.count
        return contentCount == 1
    }

    /// Whether this part contains text content.
    public var isText: Bool { text != nil }

    /// Whether this part contains raw byte content.
    public var isRaw: Bool { raw != nil }

    /// Whether this part contains a URL reference.
    public var isURL: Bool { url != nil }

    /// Whether this part contains structured data.
    public var isData: Bool { data != nil }
}

// MARK: - Factory Methods

extension Part {
    /// Creates a text part with the given string content.
    public static func text(_ text: String, metadata: [String: AnyCodable]? = nil) -> Part {
        Part(text: text, metadata: metadata, mediaType: "text/plain")
    }

    /// Creates a part with raw byte content.
    public static func raw(
        _ data: Data,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) -> Part {
        Part(raw: data, metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a part with a URL reference.
    public static func url(
        _ url: String,
        filename: String? = nil,
        mediaType: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) -> Part {
        Part(url: url, metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a part with structured data.
    public static func data(
        _ data: [String: AnyCodable],
        mediaType: String? = "application/json",
        metadata: [String: AnyCodable]? = nil
    ) -> Part {
        Part(data: AnyCodable(data), metadata: metadata, mediaType: mediaType)
    }

    /// Creates a part with any AnyCodable value as data.
    public static func data(
        _ value: AnyCodable,
        mediaType: String? = "application/json",
        metadata: [String: AnyCodable]? = nil
    ) -> Part {
        Part(data: value, metadata: metadata, mediaType: mediaType)
    }
}

// MARK: - Backward Compatibility

extension Part {
    /// Creates a file part with inline data.
    /// - Note: This is a convenience method that maps to the new `raw` content type.
    public static func file(data: Data, name: String? = nil, mediaType: String? = nil) -> Part {
        Part(raw: data, filename: name, mediaType: mediaType)
    }

    /// Creates a file part with a URI reference.
    /// - Note: This is a convenience method that maps to the new `url` content type.
    public static func file(uri: String, name: String? = nil, mediaType: String? = nil) -> Part {
        Part(url: uri, filename: name, mediaType: mediaType)
    }
}

// MARK: - Legacy Type Aliases (Deprecated)

/// Legacy text part structure.
/// - Note: Use `Part` directly with the `text` field instead.
@available(*, deprecated, message: "Use Part directly with the text field")
public struct TextPart: Codable, Sendable, Equatable {
    public let text: String
    public let metadata: [String: AnyCodable]?

    public init(text: String, metadata: [String: AnyCodable]? = nil) {
        self.text = text
        self.metadata = metadata
    }

    /// Convert to the new Part type.
    public var asPart: Part {
        Part.text(text, metadata: metadata)
    }
}

/// Legacy file part structure.
/// - Note: Use `Part` directly with either `raw` or `url` field instead.
@available(*, deprecated, message: "Use Part directly with raw or url field")
public struct FilePart: Codable, Sendable, Equatable {
    public let file: FileContent
    public let metadata: [String: AnyCodable]?

    public init(file: FileContent, metadata: [String: AnyCodable]? = nil) {
        self.file = file
        self.metadata = metadata
    }

    /// Convert to the new Part type.
    public var asPart: Part {
        if let bytes = file.fileWithBytes, let data = Data(base64Encoded: bytes) {
            return Part(raw: data, metadata: metadata, filename: file.name, mediaType: file.mediaType)
        } else if let uri = file.fileWithUri {
            return Part(url: uri, metadata: metadata, filename: file.name, mediaType: file.mediaType)
        }
        return Part(metadata: metadata, filename: file.name, mediaType: file.mediaType)
    }

    private enum CodingKeys: String, CodingKey {
        case file
        case metadata
    }
}

/// Legacy file content structure for backward compatibility.
@available(*, deprecated, message: "Use Part directly with raw or url field")
public struct FileContent: Codable, Sendable, Equatable {
    public let name: String?
    public let mediaType: String?
    public let fileWithBytes: String?
    public let fileWithUri: String?

    public init(
        name: String? = nil,
        mediaType: String? = nil,
        fileWithBytes: String? = nil,
        fileWithUri: String? = nil
    ) {
        self.name = name
        self.mediaType = mediaType
        self.fileWithBytes = fileWithBytes
        self.fileWithUri = fileWithUri
    }

    public var isValid: Bool {
        (fileWithBytes != nil) != (fileWithUri != nil)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case mediaType = "media_type"
        case fileWithBytes = "file_with_bytes"
        case fileWithUri = "file_with_uri"
    }

    public static func inline(data: Data, name: String? = nil, mediaType: String? = nil) -> FileContent {
        FileContent(name: name, mediaType: mediaType, fileWithBytes: data.base64EncodedString(), fileWithUri: nil)
    }

    public static func reference(uri: String, name: String? = nil, mediaType: String? = nil) -> FileContent {
        FileContent(name: name, mediaType: mediaType, fileWithBytes: nil, fileWithUri: uri)
    }
}

/// Legacy data part structure.
/// - Note: Use `Part` directly with the `data` field instead.
@available(*, deprecated, message: "Use Part directly with the data field")
public struct DataPart: Codable, Sendable, Equatable {
    public let data: [String: AnyCodable]
    public let metadata: [String: AnyCodable]?

    public init(data: [String: AnyCodable], metadata: [String: AnyCodable]? = nil) {
        self.data = data
        self.metadata = metadata
    }

    /// Convert to the new Part type.
    public var asPart: Part {
        Part.data(data, metadata: metadata)
    }
}
