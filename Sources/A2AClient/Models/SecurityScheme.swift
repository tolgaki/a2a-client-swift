// SecurityScheme.swift
// A2AClient
//
// Agent2Agent Protocol - Security Scheme Definitions

import Foundation

/// Represents a security scheme for agent authentication.
///
/// Security schemes define how clients authenticate with agents,
/// supporting various methods including API keys, HTTP auth, OAuth2, and more.
public struct SecurityScheme: Codable, Sendable, Equatable {
    /// The type of security scheme.
    public let type: SecuritySchemeType

    /// Human-readable description of this security scheme.
    public let description: String?

    /// For apiKey: The name of the header, query parameter, or cookie.
    public let name: String?

    /// For apiKey: Where the API key is sent (header, query, or cookie).
    public let `in`: APIKeyLocation?

    /// For http: The HTTP authentication scheme (e.g., "basic", "bearer").
    public let scheme: String?

    /// For http bearer: Format of the bearer token.
    public let bearerFormat: String?

    /// For oauth2: OAuth 2.0 flow configurations.
    public let flows: OAuthFlows?

    /// For openIdConnect: OpenID Connect discovery URL.
    public let openIdConnectUrl: String?

    public init(
        type: SecuritySchemeType,
        description: String? = nil,
        name: String? = nil,
        in location: APIKeyLocation? = nil,
        scheme: String? = nil,
        bearerFormat: String? = nil,
        flows: OAuthFlows? = nil,
        openIdConnectUrl: String? = nil
    ) {
        self.type = type
        self.description = description
        self.name = name
        self.`in` = location
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.flows = flows
        self.openIdConnectUrl = openIdConnectUrl
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case name
        case `in`
        case scheme
        case bearerFormat
        case flows
        case openIdConnectUrl
        // .NET wrapper keys — discriminated-union encoding that nests the
        // scheme fields inside a typed wrapper object.
        case httpAuthSecurityScheme
        case apiKeySecurityScheme
        case oauth2SecurityScheme
        case openIdConnectSecurityScheme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // .NET A2A SDK encodes security schemes as a discriminated union:
        //   { "httpAuthSecurityScheme": { "scheme": "bearer", ... } }
        // Detect the wrapper key and decode the inner object.
        if container.contains(.httpAuthSecurityScheme) {
            let inner = try container.decode(SecurityScheme.InnerHTTP.self, forKey: .httpAuthSecurityScheme)
            self.type = .http; self.scheme = inner.scheme; self.bearerFormat = inner.bearerFormat
            self.description = inner.description; self.name = nil; self.in = nil
            self.flows = nil; self.openIdConnectUrl = nil
            return
        }
        if container.contains(.apiKeySecurityScheme) {
            let inner = try container.decode(SecurityScheme.InnerAPIKey.self, forKey: .apiKeySecurityScheme)
            self.type = .apiKey; self.name = inner.name; self.in = inner.in
            self.description = inner.description; self.scheme = nil; self.bearerFormat = nil
            self.flows = nil; self.openIdConnectUrl = nil
            return
        }
        if container.contains(.oauth2SecurityScheme) {
            let inner = try container.decode(SecurityScheme.InnerOAuth2.self, forKey: .oauth2SecurityScheme)
            self.type = .oauth2; self.flows = inner.flows
            self.description = inner.description; self.name = nil; self.in = nil
            self.scheme = nil; self.bearerFormat = nil; self.openIdConnectUrl = nil
            return
        }
        if container.contains(.openIdConnectSecurityScheme) {
            let inner = try container.decode(SecurityScheme.InnerOIDC.self, forKey: .openIdConnectSecurityScheme)
            self.type = .openIdConnect; self.openIdConnectUrl = inner.openIdConnectUrl
            self.description = inner.description; self.name = nil; self.in = nil
            self.scheme = nil; self.bearerFormat = nil; self.flows = nil
            return
        }

        // Standard flat format
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.`in` = try container.decodeIfPresent(APIKeyLocation.self, forKey: .in)
        self.scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        self.bearerFormat = try container.decodeIfPresent(String.self, forKey: .bearerFormat)
        self.flows = try container.decodeIfPresent(OAuthFlows.self, forKey: .flows)
        self.openIdConnectUrl = try container.decodeIfPresent(String.self, forKey: .openIdConnectUrl)

        if let explicit = try container.decodeIfPresent(SecuritySchemeType.self, forKey: .type) {
            self.type = explicit
        } else if self.flows != nil {
            self.type = .oauth2
        } else if self.openIdConnectUrl != nil {
            self.type = .openIdConnect
        } else if self.scheme != nil {
            self.type = .http
        } else if self.name != nil || self.`in` != nil {
            self.type = .apiKey
        } else {
            self.type = .http  // safe default — prefer not to crash on unknown schemes
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(`in`, forKey: .in)
        try container.encodeIfPresent(scheme, forKey: .scheme)
        try container.encodeIfPresent(bearerFormat, forKey: .bearerFormat)
        try container.encodeIfPresent(flows, forKey: .flows)
        try container.encodeIfPresent(openIdConnectUrl, forKey: .openIdConnectUrl)
    }

    // MARK: - .NET Wrapper Inner Types

    private struct InnerHTTP: Decodable {
        let scheme: String?
        let bearerFormat: String?
        let description: String?
    }

    private struct InnerAPIKey: Decodable {
        let name: String?
        let `in`: APIKeyLocation?
        let description: String?
    }

    private struct InnerOAuth2: Decodable {
        let flows: OAuthFlows?
        let description: String?
    }

    private struct InnerOIDC: Decodable {
        let openIdConnectUrl: String?
        let description: String?
    }
}

// MARK: - SecuritySchemeType

/// Types of security schemes supported by A2A.
public enum SecuritySchemeType: String, Codable, Sendable, Equatable {
    /// API key authentication.
    case apiKey

    /// HTTP authentication (Basic, Bearer, etc.).
    case http

    /// OAuth 2.0 authentication.
    case oauth2

    /// OpenID Connect authentication.
    case openIdConnect

    /// Mutual TLS authentication.
    case mutualTLS
}

// MARK: - APIKeyLocation

/// Where an API key is transmitted.
public enum APIKeyLocation: String, Codable, Sendable, Equatable {
    /// API key sent in HTTP header.
    case header

    /// API key sent in query parameter.
    case query

    /// API key sent in cookie.
    case cookie
}

// MARK: - OAuthFlows

/// OAuth 2.0 flow configurations.
public struct OAuthFlows: Codable, Sendable, Equatable {
    /// Authorization code flow configuration.
    public let authorizationCode: OAuthFlow?

    /// Client credentials flow configuration.
    public let clientCredentials: OAuthFlow?

    /// Implicit flow configuration.
    public let implicit: OAuthFlow?

    /// Password flow configuration.
    public let password: OAuthFlow?

    public init(
        authorizationCode: OAuthFlow? = nil,
        clientCredentials: OAuthFlow? = nil,
        implicit: OAuthFlow? = nil,
        password: OAuthFlow? = nil
    ) {
        self.authorizationCode = authorizationCode
        self.clientCredentials = clientCredentials
        self.implicit = implicit
        self.password = password
    }
}

// MARK: - OAuthFlow

/// Configuration for a specific OAuth 2.0 flow.
public struct OAuthFlow: Codable, Sendable, Equatable {
    /// Authorization URL (for authorization code and implicit flows).
    public let authorizationUrl: String?

    /// Token URL (for authorization code, client credentials, and password flows).
    public let tokenUrl: String?

    /// Refresh URL for obtaining new tokens.
    public let refreshUrl: String?

    /// Available scopes for this flow.
    public let scopes: [String: String]?

    public init(
        authorizationUrl: String? = nil,
        tokenUrl: String? = nil,
        refreshUrl: String? = nil,
        scopes: [String: String]? = nil
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }
}

// MARK: - Convenience Factories

extension SecurityScheme {
    /// Creates an API key security scheme.
    public static func apiKey(
        name: String,
        in location: APIKeyLocation,
        description: String? = nil
    ) -> SecurityScheme {
        SecurityScheme(
            type: .apiKey,
            description: description,
            name: name,
            in: location
        )
    }

    /// Creates an HTTP Basic authentication scheme.
    public static func httpBasic(description: String? = nil) -> SecurityScheme {
        SecurityScheme(
            type: .http,
            description: description,
            scheme: "basic"
        )
    }

    /// Creates an HTTP Bearer authentication scheme.
    public static func httpBearer(
        format: String? = nil,
        description: String? = nil
    ) -> SecurityScheme {
        SecurityScheme(
            type: .http,
            description: description,
            scheme: "bearer",
            bearerFormat: format
        )
    }

    /// Creates an OAuth 2.0 security scheme with client credentials flow.
    public static func oauth2ClientCredentials(
        tokenUrl: String,
        scopes: [String: String]? = nil,
        description: String? = nil
    ) -> SecurityScheme {
        SecurityScheme(
            type: .oauth2,
            description: description,
            flows: OAuthFlows(
                clientCredentials: OAuthFlow(
                    tokenUrl: tokenUrl,
                    scopes: scopes
                )
            )
        )
    }

    /// Creates an OAuth 2.0 security scheme with authorization code flow.
    public static func oauth2AuthorizationCode(
        authorizationUrl: String,
        tokenUrl: String,
        scopes: [String: String]? = nil,
        description: String? = nil
    ) -> SecurityScheme {
        SecurityScheme(
            type: .oauth2,
            description: description,
            flows: OAuthFlows(
                authorizationCode: OAuthFlow(
                    authorizationUrl: authorizationUrl,
                    tokenUrl: tokenUrl,
                    scopes: scopes
                )
            )
        )
    }

    /// Creates an OpenID Connect security scheme.
    public static func openIdConnect(
        discoveryUrl: String,
        description: String? = nil
    ) -> SecurityScheme {
        SecurityScheme(
            type: .openIdConnect,
            description: description,
            openIdConnectUrl: discoveryUrl
        )
    }

    /// Creates a Mutual TLS security scheme.
    public static func mutualTLS(description: String? = nil) -> SecurityScheme {
        SecurityScheme(
            type: .mutualTLS,
            description: description
        )
    }
}
