// AgentCard.swift
// A2AClient
//
// Agent2Agent Protocol - Agent Card Definitions

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

    /// The service endpoint URL for the agent.
    public let url: String

    /// Provider information for the agent.
    public let provider: AgentProvider?

    /// Version of the agent implementation.
    public let version: String

    /// A2A protocol version supported by this agent.
    public let protocolVersion: String

    /// Supported interfaces (endpoints) for this agent.
    public let supportedInterfaces: [AgentInterface]

    /// Capabilities supported by this agent.
    public let capabilities: AgentCapabilities

    /// Security schemes supported by this agent.
    public let securitySchemes: [String: SecurityScheme]?

    /// Security requirements for accessing this agent.
    public let security: [[String: [String]]]?

    /// Default input modes accepted by this agent.
    public let defaultInputModes: [String]

    /// Default output modes produced by this agent.
    public let defaultOutputModes: [String]

    /// Skills (capabilities) offered by this agent.
    public let skills: [AgentSkill]

    /// Whether this agent supports extended agent card retrieval.
    public let supportsExtendedAgentCard: Bool?

    /// Documentation URL for this agent.
    public let documentationUrl: String?

    /// Optional icon URL for the agent.
    public let iconUrl: String?

    /// Optional JWS signatures for this agent card.
    public let signatures: [AgentCardSignature]?

    public init(
        name: String,
        description: String,
        url: String,
        provider: AgentProvider? = nil,
        version: String,
        protocolVersion: String = "1.0",
        supportedInterfaces: [AgentInterface] = [.defaultInterface],
        capabilities: AgentCapabilities = AgentCapabilities(),
        securitySchemes: [String: SecurityScheme]? = nil,
        security: [[String: [String]]]? = nil,
        defaultInputModes: [String] = ["text/plain"],
        defaultOutputModes: [String] = ["text/plain"],
        skills: [AgentSkill] = [],
        supportsExtendedAgentCard: Bool? = nil,
        documentationUrl: String? = nil,
        iconUrl: String? = nil,
        signatures: [AgentCardSignature]? = nil
    ) {
        self.name = name
        self.description = description
        self.url = url
        self.provider = provider
        self.version = version
        self.protocolVersion = protocolVersion
        self.supportedInterfaces = supportedInterfaces
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.security = security
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.supportsExtendedAgentCard = supportsExtendedAgentCard
        self.documentationUrl = documentationUrl
        self.iconUrl = iconUrl
        self.signatures = signatures
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case url
        case provider
        case version
        case protocolVersion = "protocol_version"
        case supportedInterfaces = "supported_interfaces"
        case capabilities
        case securitySchemes = "security_schemes"
        case security
        case defaultInputModes = "default_input_modes"
        case defaultOutputModes = "default_output_modes"
        case skills
        case supportsExtendedAgentCard = "supports_extended_agent_card"
        case documentationUrl = "documentation_url"
        case iconUrl = "icon_url"
        case signatures
    }
}

// MARK: - AgentInterface

/// Represents a supported interface (endpoint type) for an agent.
public struct AgentInterface: Codable, Sendable, Equatable {
    /// The interface type (e.g., "default", "streaming").
    public let type: String

    /// Optional URL for this specific interface.
    public let url: String?

    public init(type: String, url: String? = nil) {
        self.type = type
        self.url = url
    }

    /// Default interface.
    public static let defaultInterface = AgentInterface(type: "default")

    /// Streaming interface.
    public static let streaming = AgentInterface(type: "streaming")
}

// MARK: - AgentProvider

/// Information about the agent's provider/operator.
public struct AgentProvider: Codable, Sendable, Equatable {
    /// Name of the organization providing the agent.
    public let organization: String

    /// URL of the provider's website.
    public let url: String?

    public init(organization: String, url: String? = nil) {
        self.organization = organization
        self.url = url
    }
}

// MARK: - AgentCapabilities

/// Capabilities supported by an agent.
public struct AgentCapabilities: Codable, Sendable, Equatable {
    /// Whether the agent supports streaming responses.
    public let streaming: Bool?

    /// Whether the agent supports push notifications.
    public let pushNotifications: Bool?

    /// Whether the agent supports state transition history.
    public let stateTransitionHistory: Bool?

    /// Extensions supported by this agent.
    public let extensions: [AgentExtension]?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        stateTransitionHistory: Bool? = nil,
        extensions: [AgentExtension]? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.stateTransitionHistory = stateTransitionHistory
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case streaming
        case pushNotifications = "push_notifications"
        case stateTransitionHistory = "state_transition_history"
        case extensions
    }
}

// MARK: - AgentExtension

/// An extension supported by an agent.
public struct AgentExtension: Codable, Sendable, Equatable {
    /// URI identifying the extension.
    public let uri: String

    /// Whether this extension is required for interaction.
    public let required: Bool?

    /// Human-readable description of the extension.
    public let description: String?

    public init(uri: String, required: Bool? = nil, description: String? = nil) {
        self.uri = uri
        self.required = required
        self.description = description
    }
}

// MARK: - AgentSkill

/// A skill (capability) offered by an agent.
public struct AgentSkill: Codable, Sendable, Equatable, Identifiable {
    /// Unique identifier for this skill.
    public let id: String

    /// Human-readable name of the skill.
    public let name: String

    /// Human-readable description of the skill.
    public let description: String

    /// Tags for categorizing this skill.
    public let tags: [String]

    /// Input modes accepted by this skill.
    public let inputModes: [String]?

    /// Output modes produced by this skill.
    public let outputModes: [String]?

    /// Example prompts demonstrating skill usage.
    public let examples: [String]?

    /// Security requirements specific to this skill.
    public let security: [[String: [String]]]?

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String] = [],
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        examples: [String]? = nil,
        security: [[String: [String]]]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.examples = examples
        self.security = security
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case tags
        case inputModes = "input_modes"
        case outputModes = "output_modes"
        case examples
        case security
    }
}

// MARK: - AgentCardSignature

/// JWS signature for agent card verification.
public struct AgentCardSignature: Codable, Sendable, Equatable {
    /// The signature algorithm used.
    public let algorithm: String

    /// The key ID used for signing.
    public let keyId: String?

    /// The JWS signature value.
    public let signature: String

    public init(algorithm: String, keyId: String? = nil, signature: String) {
        self.algorithm = algorithm
        self.keyId = keyId
        self.signature = signature
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case keyId = "key_id"
        case signature
    }
}

// MARK: - Well-Known URI

extension AgentCard {
    /// The well-known URI path for agent card discovery.
    public static let wellKnownPath = "/.well-known/agent.json"

    /// Constructs the well-known agent card URL for a given base URL.
    public static func wellKnownURL(for baseURL: URL) -> URL {
        baseURL.appendingPathComponent(".well-known/agent.json")
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
