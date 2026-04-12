// AgentCard.swift
// A2AClient
//
// Agent2Agent Protocol - Agent Card Definitions
// Spec: https://a2a-protocol.org/latest/specification/#441-agentcard

import Foundation

/// Represents an Agent Card - metadata describing an agent's capabilities and configuration.
///
/// Agent Cards serve as a "digital business card" for agents, enabling discovery
/// and providing information needed to interact with the agent.
public struct AgentCard: Codable, Sendable, Equatable {
    /// Human-readable name of the agent.
    public let name: String

    /// Human-readable description of the agent's purpose and capabilities.
    public let description: String

    /// Ordered list of supported interfaces. First entry is preferred.
    public let supportedInterfaces: [AgentInterface]

    /// Provider information for the agent.
    public let provider: AgentProvider?

    /// Version of the agent implementation.
    public let version: String

    /// Documentation URL for this agent.
    public let documentationUrl: String?

    /// Capabilities supported by this agent.
    public let capabilities: AgentCapabilities

    /// Security schemes supported by this agent (keyed by scheme name).
    public let securitySchemes: [String: SecurityScheme]?

    /// Security requirements for accessing this agent.
    public let securityRequirements: [SecurityRequirement]?

    /// Default input modes accepted by this agent (media types).
    public let defaultInputModes: [String]

    /// Default output modes produced by this agent (media types).
    public let defaultOutputModes: [String]

    /// Skills (capabilities) offered by this agent.
    public let skills: [AgentSkill]

    /// Optional JWS signatures for this agent card.
    public let signatures: [AgentCardSignature]?

    /// Optional icon URL for the agent.
    public let iconUrl: String?

    public init(
        name: String,
        description: String,
        supportedInterfaces: [AgentInterface],
        provider: AgentProvider? = nil,
        version: String,
        documentationUrl: String? = nil,
        capabilities: AgentCapabilities = AgentCapabilities(),
        securitySchemes: [String: SecurityScheme]? = nil,
        securityRequirements: [SecurityRequirement]? = nil,
        defaultInputModes: [String] = ["text/plain"],
        defaultOutputModes: [String] = ["text/plain"],
        skills: [AgentSkill] = [],
        signatures: [AgentCardSignature]? = nil,
        iconUrl: String? = nil
    ) {
        precondition(!supportedInterfaces.isEmpty, "AgentCard must have at least one supported interface per A2A spec")
        self.name = name
        self.description = description
        self.supportedInterfaces = supportedInterfaces
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.securityRequirements = securityRequirements
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.signatures = signatures
        self.iconUrl = iconUrl
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case supportedInterfaces
        case provider
        case version
        case documentationUrl
        case capabilities
        case securitySchemes
        case securityRequirements
        case defaultInputModes
        case defaultOutputModes
        case skills
        case signatures
        case iconUrl
        // v0.3 legacy keys
        case url
        case protocolVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)

        if let interfaces = try container.decodeIfPresent([AgentInterface].self, forKey: .supportedInterfaces),
           !interfaces.isEmpty {
            // v1.0 format: has supportedInterfaces array
            self.supportedInterfaces = interfaces
        } else if let url = try container.decodeIfPresent(String.self, forKey: .url) {
            // v0.3 legacy format: has top-level "url" and "protocolVersion" fields
            let protocolVersion = try container.decodeIfPresent(String.self, forKey: .protocolVersion) ?? "0.3"
            self.supportedInterfaces = [AgentInterface(url: url, protocolBinding: AgentInterface.jsonRPC, protocolVersion: protocolVersion)]
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .supportedInterfaces,
                in: container,
                debugDescription: "AgentCard must have 'supportedInterfaces' (v1.0) or 'url' (v0.3)"
            )
        }

        self.provider = try container.decodeIfPresent(AgentProvider.self, forKey: .provider)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        self.documentationUrl = try container.decodeIfPresent(String.self, forKey: .documentationUrl)
        self.capabilities = try container.decodeIfPresent(AgentCapabilities.self, forKey: .capabilities) ?? AgentCapabilities()
        self.securitySchemes = try container.decodeIfPresent([String: SecurityScheme].self, forKey: .securitySchemes)
        self.securityRequirements = try container.decodeIfPresent([SecurityRequirement].self, forKey: .securityRequirements)
        self.defaultInputModes = try container.decodeIfPresent([String].self, forKey: .defaultInputModes) ?? ["text/plain"]
        self.defaultOutputModes = try container.decodeIfPresent([String].self, forKey: .defaultOutputModes) ?? ["text/plain"]
        self.skills = try container.decodeIfPresent([AgentSkill].self, forKey: .skills) ?? []
        self.signatures = try container.decodeIfPresent([AgentCardSignature].self, forKey: .signatures)
        self.iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(supportedInterfaces, forKey: .supportedInterfaces)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(documentationUrl, forKey: .documentationUrl)
        try container.encodeIfPresent(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(securitySchemes, forKey: .securitySchemes)
        try container.encodeIfPresent(securityRequirements, forKey: .securityRequirements)
        try container.encodeIfPresent(defaultInputModes, forKey: .defaultInputModes)
        try container.encodeIfPresent(defaultOutputModes, forKey: .defaultOutputModes)
        try container.encodeIfPresent(skills, forKey: .skills)
        try container.encodeIfPresent(signatures, forKey: .signatures)
        try container.encodeIfPresent(iconUrl, forKey: .iconUrl)
    }
}

// MARK: - AgentCard Convenience

extension AgentCard {
    /// Returns the primary/preferred interface URL.
    public var url: String? {
        supportedInterfaces.first?.url
    }

    /// Returns the protocol version from the primary interface.
    public var protocolVersion: String? {
        supportedInterfaces.first?.protocolVersion
    }

    /// Returns the protocol binding from the primary interface.
    public var protocolBinding: String? {
        supportedInterfaces.first?.protocolBinding
    }
}

// MARK: - AgentInterface

/// Declares a combination of target URL, transport and protocol version for interacting with an agent.
/// This allows agents to expose functionality over multiple protocol binding mechanisms.
public struct AgentInterface: Codable, Sendable, Equatable {
    /// The URL where this interface is available.
    /// Must be a valid absolute HTTPS URL in production.
    public let url: String

    /// The protocol binding supported at this URL.
    /// Core values: "JSONRPC", "GRPC", "HTTP+JSON"
    public let protocolBinding: String

    /// Optional tenant to be set in requests when calling the agent.
    public let tenant: String?

    /// The version of the A2A protocol this interface exposes.
    /// Examples: "0.3", "1.0"
    public let protocolVersion: String

    public init(
        url: String,
        protocolBinding: String = "HTTP+JSON",
        tenant: String? = nil,
        protocolVersion: String = "1.0"
    ) {
        self.url = url
        self.protocolBinding = protocolBinding
        self.tenant = tenant
        self.protocolVersion = protocolVersion
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case protocolBinding
        case tenant
        case protocolVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(String.self, forKey: .url)
        self.protocolBinding = try container.decodeIfPresent(String.self, forKey: .protocolBinding) ?? AgentInterface.httpJSON
        self.tenant = try container.decodeIfPresent(String.self, forKey: .tenant)
        self.protocolVersion = try container.decodeIfPresent(String.self, forKey: .protocolVersion) ?? "1.0"
    }

    // MARK: - Protocol Binding Constants

    /// JSON-RPC 2.0 protocol binding.
    public static let jsonRPC = "JSONRPC"

    /// gRPC protocol binding.
    public static let grpc = "GRPC"

    /// HTTP+JSON (REST) protocol binding.
    public static let httpJSON = "HTTP+JSON"
}

// MARK: - AgentProvider

/// Information about the agent's provider/operator.
public struct AgentProvider: Codable, Sendable, Equatable {
    /// URL for the provider's website or documentation.
    public let url: String

    /// Name of the organization providing the agent.
    public let organization: String

    public init(organization: String, url: String) {
        self.organization = organization
        self.url = url
    }

    /// Creates an AgentProvider with an optional URL.
    /// - Note: Per A2A spec, url is now required. This initializer is provided
    ///   for backward compatibility during migration.
    @available(*, deprecated, message: "url is now required per A2A spec. Use init(organization:url:) instead.")
    public init(organization: String, url: String? = nil) {
        self.organization = organization
        self.url = url ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case organization
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.organization = try container.decode(String.self, forKey: .organization)
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

// MARK: - AgentCapabilities

/// Capabilities supported by an agent.
public struct AgentCapabilities: Codable, Sendable, Equatable {
    /// Whether the agent supports streaming responses.
    public let streaming: Bool?

    /// Whether the agent supports push notifications.
    public let pushNotifications: Bool?

    /// Extensions supported by this agent.
    public let extensions: [AgentExtension]?

    /// Whether the agent supports providing an extended agent card when authenticated.
    public let extendedAgentCard: Bool?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        extensions: [AgentExtension]? = nil,
        extendedAgentCard: Bool? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.extensions = extensions
        self.extendedAgentCard = extendedAgentCard
    }

    private enum CodingKeys: String, CodingKey {
        case streaming
        case pushNotifications
        case extensions
        case extendedAgentCard
    }
}

// MARK: - AgentExtension

/// A declaration of a protocol extension supported by an Agent.
public struct AgentExtension: Codable, Sendable, Equatable {
    /// The unique URI identifying the extension.
    public let uri: String

    /// A human-readable description of how this agent uses the extension.
    public let description: String?

    /// If true, the client must understand and comply with the extension's requirements.
    public let required: Bool?

    /// Optional, extension-specific configuration parameters.
    public let params: [String: AnyCodable]?

    public init(
        uri: String,
        description: String? = nil,
        required: Bool? = nil,
        params: [String: AnyCodable]? = nil
    ) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }
}

// MARK: - AgentSkill

/// Represents a distinct capability or function that an agent can perform.
public struct AgentSkill: Codable, Sendable, Equatable, Identifiable {
    /// A unique identifier for the skill.
    public let id: String

    /// A human-readable name for the skill.
    public let name: String

    /// A detailed description of the skill.
    public let description: String

    /// A set of keywords describing the skill's capabilities.
    public let tags: [String]

    /// Example prompts or scenarios that this skill can handle.
    public let examples: [String]?

    /// Input modes accepted by this skill (overrides agent defaults).
    public let inputModes: [String]?

    /// Output modes produced by this skill (overrides agent defaults).
    public let outputModes: [String]?

    /// Security requirements specific to this skill.
    public let securityRequirements: [SecurityRequirement]?

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String] = [],
        examples: [String]? = nil,
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        securityRequirements: [SecurityRequirement]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.securityRequirements = securityRequirements
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case tags
        case examples
        case inputModes
        case outputModes
        case securityRequirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.examples = try container.decodeIfPresent([String].self, forKey: .examples)
        self.inputModes = try container.decodeIfPresent([String].self, forKey: .inputModes)
        self.outputModes = try container.decodeIfPresent([String].self, forKey: .outputModes)
        self.securityRequirements = try container.decodeIfPresent([SecurityRequirement].self, forKey: .securityRequirements)
    }
}

// MARK: - SecurityRequirement

/// Security requirement mapping scheme names to required scopes.
public struct SecurityRequirement: Codable, Sendable, Equatable {
    /// Map of security scheme names to their required scopes.
    public let schemes: [String: [String]]

    public init(schemes: [String: [String]]) {
        self.schemes = schemes
    }

    public init(from decoder: Decoder) throws {
        // Standard format: {"scheme_name": ["scope1", "scope2"]}
        if let container = try? decoder.singleValueContainer(),
           let flat = try? container.decode([String: [String]].self) {
            self.schemes = flat
            return
        }

        // .NET format: {"schemes": {"scheme_name": {"list": []}}}
        let keyed = try decoder.container(keyedBy: DotNetKeys.self)
        if let wrapped = try keyed.decodeIfPresent([String: DotNetScopeList].self, forKey: .schemes) {
            self.schemes = wrapped.mapValues { $0.list ?? [] }
            return
        }

        self.schemes = [:]
    }

    private enum DotNetKeys: String, CodingKey { case schemes }
    private struct DotNetScopeList: Decodable {
        let list: [String]?
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(schemes)
    }
}

// MARK: - AgentCardSignature

/// JWS signature for agent card verification.
/// Follows the JSON format of RFC 7515 JSON Web Signature (JWS).
public struct AgentCardSignature: Codable, Sendable, Equatable {
    /// The protected JWS header (base64url-encoded JSON object).
    public let protected: String

    /// The computed signature (base64url-encoded).
    public let signature: String

    /// The unprotected JWS header values.
    public let header: [String: AnyCodable]?

    public init(protected: String, signature: String, header: [String: AnyCodable]? = nil) {
        self.protected = protected
        self.signature = signature
        self.header = header
    }
}

// MARK: - Well-Known URI

extension AgentCard {
    /// The well-known URI path for agent card discovery per spec §8.2.
    public static let wellKnownPath = "/.well-known/agent-card.json"

    /// Alternative well-known path used by some early v1.0 implementations.
    public static let alternateWellKnownPath = "/.well-known/agent.json"

    /// Constructs the well-known agent card URL for a given base URL.
    public static func wellKnownURL(for baseURL: URL) -> URL {
        baseURL.appendingPathComponent(".well-known/agent-card.json")
    }

    /// Constructs the well-known agent card URL for a given domain.
    public static func wellKnownURL(domain: String, scheme: String = "https") -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = domain
        components.path = wellKnownPath
        return components.url
    }
}
