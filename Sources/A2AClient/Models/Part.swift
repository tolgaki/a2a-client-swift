// Part.swift
// A2AClient
//
// Agent2Agent Protocol - Content Part Definitions

import Foundation

/// Represents a content part within a Message or Artifact.
///
/// Parts are the smallest unit of content in the A2A protocol, supporting
/// text, files, and structured data.
public enum Part: Codable, Sendable, Equatable {
    /// Plain text content.
    case text(TextPart)

    /// File content, either inline (base64) or by reference (URI).
    case file(FilePart)

    /// Structured JSON data.
    case data(DataPart)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case file
        case data
        case metadata
    }

    private enum PartType: String, Codable {
        case text
        case file
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PartType.self, forKey: .type)

        switch type {
        case .text:
            self = .text(try TextPart(from: decoder))
        case .file:
            self = .file(try FilePart(from: decoder))
        case .data:
            self = .data(try DataPart(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let part):
            try part.encode(to: encoder)
        case .file(let part):
            try part.encode(to: encoder)
        case .data(let part):
            try part.encode(to: encoder)
        }
    }
}

// MARK: - TextPart

/// A text content part containing plain text.
public struct TextPart: Codable, Sendable, Equatable {
    /// The type identifier for this part.
    public let type: String = "text"

    /// The text content.
    public let text: String

    /// Optional metadata associated with this part.
    public let metadata: [String: AnyCodable]?

    public init(text: String, metadata: [String: AnyCodable]? = nil) {
        self.text = text
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case metadata
    }
}

// MARK: - FilePart

/// A file content part containing either inline data or a URI reference.
public struct FilePart: Codable, Sendable, Equatable {
    /// The type identifier for this part.
    public let type: String = "file"

    /// The file content.
    public let file: FileContent

    /// Optional metadata associated with this part.
    public let metadata: [String: AnyCodable]?

    public init(file: FileContent, metadata: [String: AnyCodable]? = nil) {
        self.file = file
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case file
        case metadata
    }
}

/// Represents file content with either inline bytes or a URI reference.
public struct FileContent: Codable, Sendable, Equatable {
    /// Optional human-readable name for the file.
    public let name: String?

    /// MIME type of the file content.
    public let mediaType: String?

    /// Base64-encoded file content (mutually exclusive with uri).
    public let fileWithBytes: String?

    /// URI reference to the file (mutually exclusive with fileWithBytes).
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

    /// Validates that this FileContent has exactly one of fileWithBytes or fileWithUri.
    public var isValid: Bool {
        (fileWithBytes != nil) != (fileWithUri != nil)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case mediaType = "media_type"
        case fileWithBytes = "file_with_bytes"
        case fileWithUri = "file_with_uri"
    }

    /// Creates a FileContent with inline base64-encoded data.
    public static func inline(
        data: Data,
        name: String? = nil,
        mediaType: String? = nil
    ) -> FileContent {
        FileContent(
            name: name,
            mediaType: mediaType,
            fileWithBytes: data.base64EncodedString(),
            fileWithUri: nil
        )
    }

    /// Creates a FileContent with a URI reference.
    public static func reference(
        uri: String,
        name: String? = nil,
        mediaType: String? = nil
    ) -> FileContent {
        FileContent(
            name: name,
            mediaType: mediaType,
            fileWithBytes: nil,
            fileWithUri: uri
        )
    }

    /// Returns the bytes data if this is an inline file.
    public var bytes: String? { fileWithBytes }

    /// Returns the URI if this is a reference file.
    public var uri: String? { fileWithUri }

    /// Returns true if this file has inline content.
    public var isInline: Bool { fileWithBytes != nil }

    /// Returns true if this file is a URI reference.
    public var isReference: Bool { fileWithUri != nil }
}

// MARK: - DataPart

/// A structured data content part containing JSON data.
public struct DataPart: Codable, Sendable, Equatable {
    /// The type identifier for this part.
    public let type: String = "data"

    /// The structured data content.
    public let data: [String: AnyCodable]

    /// Optional metadata associated with this part.
    public let metadata: [String: AnyCodable]?

    public init(data: [String: AnyCodable], metadata: [String: AnyCodable]? = nil) {
        self.data = data
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case data
        case metadata
    }
}

// MARK: - Convenience Extensions

extension Part {
    /// Creates a text part with the given string content.
    public static func text(_ text: String) -> Part {
        .text(TextPart(text: text))
    }

    /// Creates a file part with inline data.
    public static func file(data: Data, name: String? = nil, mediaType: String? = nil) -> Part {
        .file(FilePart(file: .inline(data: data, name: name, mediaType: mediaType)))
    }

    /// Creates a file part with a URI reference.
    public static func file(uri: String, name: String? = nil, mediaType: String? = nil) -> Part {
        .file(FilePart(file: .reference(uri: uri, name: name, mediaType: mediaType)))
    }

    /// Creates a data part with the given dictionary.
    public static func data(_ data: [String: AnyCodable]) -> Part {
        .data(DataPart(data: data))
    }
}

// MARK: - Backward Compatibility

extension Part {
    /// Creates a file part with inline data (backward compatible).
    @available(*, deprecated, renamed: "file(data:name:mediaType:)")
    public static func file(data: Data, name: String? = nil, mimeType: String?) -> Part {
        .file(FilePart(file: .inline(data: data, name: name, mediaType: mimeType)))
    }

    /// Creates a file part with a URI reference (backward compatible).
    @available(*, deprecated, renamed: "file(uri:name:mediaType:)")
    public static func file(uri: String, name: String? = nil, mimeType: String?) -> Part {
        .file(FilePart(file: .reference(uri: uri, name: name, mediaType: mimeType)))
    }
}
