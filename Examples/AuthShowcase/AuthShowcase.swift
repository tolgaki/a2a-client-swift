// AuthShowcase.swift
// A2AClient Example
//
// Builds an `A2AClient` for every authentication scheme that ships with
// the SDK and prints a one-line summary of the configuration so you can
// pick the right approach for your deployment.
//
// What this sample shows
// ----------------------
// • All five built-in authentication providers:
//     1. `NoAuthentication`           — public agents.
//     2. `APIKeyAuthentication`       — header / query / cookie key.
//     3. `BearerAuthentication`       — static JWT or OAuth bearer.
//     4. `BasicAuthentication`        — HTTP Basic.
//     5. `OAuth2Authentication`       — actor-based provider that
//                                       refreshes tokens on demand.
// • The custom-provider extension point — implementing
//   `AuthenticationProvider` for HMAC-signed requests.
// • `CompositeAuthentication` for chaining multiple providers (for
//   example: an API key for the gateway *and* a bearer token for the
//   downstream agent).
// • The `with(...)` builder methods on `A2AClientConfiguration`.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • `AgentCard.securitySchemes` advertises which schemes a 1.0 agent
//   accepts. Matching the scheme to a Swift provider is purely a client
//   concern, but this sample lays out the canonical mapping table.
// • `OAuth2Authentication` is an actor — its public surface is `async`
//   and it refreshes / rotates access tokens automatically when the
//   stored expiry passes.
// • Any provider can be passed once via `A2AClientConfiguration` and
//   the SDK will apply it to every outbound request, including
//   streaming and push-notification CRUD calls.
//
// Note
// ----
// This sample never connects to a network — it just constructs clients
// and prints what would happen. That makes it safe to run in CI and
// useful as a working spec of the auth API.

import A2AClient
import Foundation

@main
struct AuthShowcase {
    static func main() async {
        let baseURL = URL(string: "https://agent.example.com")!
        print("AuthShowcase → \(baseURL.absoluteString)")
        print("==========================================")

        // 1. No authentication — public agents and local development.
        section("1. NoAuthentication")
        do {
            let config = A2AClientConfiguration(baseURL: baseURL)
            let client = A2AClient(configuration: config)
            print("    transport: \(config.transportBinding.rawValue)")
            print("    auth     : \(client.configuration.authenticationProvider == nil ? "none" : "set")")
        }

        // 2. API key — works for header, query string, or cookie.
        section("2. APIKeyAuthentication")
        do {
            // Header (most common) — `X-API-Key: <secret>`.
            let headerConfig = A2AClientConfiguration(baseURL: baseURL)
                .withAPIKey("sk-demo-1234", name: "X-API-Key", location: .header)
            describe(headerConfig, label: "header  ")

            // Query string — `?api_key=<secret>`.
            let queryConfig = A2AClientConfiguration(baseURL: baseURL)
                .withAPIKey("sk-demo-1234", name: "api_key", location: .query)
            describe(queryConfig, label: "query   ")

            // Cookie — `Cookie: session=<secret>`.
            let cookieConfig = A2AClientConfiguration(baseURL: baseURL)
                .withAPIKey("sk-demo-1234", name: "session", location: .cookie)
            describe(cookieConfig, label: "cookie  ")
        }

        // 3. Bearer — static JWT, opaque tokens, etc.
        section("3. BearerAuthentication")
        do {
            let config = A2AClientConfiguration(baseURL: baseURL)
                .withBearerToken("eyJhbGciOiJIUzI1NiJ9.demo.payload")
            describe(config)
        }

        // 4. HTTP Basic — username + password, base64-encoded.
        section("4. BasicAuthentication")
        do {
            let config = A2AClientConfiguration(baseURL: baseURL)
                .withBasicAuth(username: "alice", password: "correct horse battery staple")
            describe(config)
        }

        // 5. OAuth 2.0 — handles refresh tokens & client_credentials.
        section("5. OAuth2Authentication")
        do {
            // The provider is an actor: construct it once, hand it to as
            // many clients as you like, and it will keep its tokens
            // synchronized.
            let oauth = OAuth2Authentication(
                configuration: .init(
                    tokenUrl: "https://auth.example.com/oauth/token",
                    clientId: "my-app",
                    clientSecret: "shhh",
                    scopes: ["a2a.read", "a2a.write"]
                )
            )

            // If you already have a token from another flow you can seed
            // the provider so it skips the initial token request.
            await oauth.setAccessToken(
                "preloaded-access-token",
                refreshToken: "preloaded-refresh-token",
                expiresIn: 3600
            )

            let config = A2AClientConfiguration(baseURL: baseURL)
                .with(authenticationProvider: oauth)
            describe(config)
            print("    note     : token refresh happens lazily on the next request.")
        }

        // 6. Custom provider — sign requests yourself.
        section("6. Custom AuthenticationProvider")
        do {
            let signer = HMACSigner(keyId: "demo-key", secret: Data("supersecret".utf8))
            let config = A2AClientConfiguration(baseURL: baseURL)
                .with(authenticationProvider: signer)
            describe(config)
        }

        // 7. Composite — chain providers (e.g. API key + bearer).
        section("7. CompositeAuthentication")
        do {
            let composite = CompositeAuthentication(providers: [
                APIKeyAuthentication(key: "gateway-key", name: "X-Gateway-Key", location: .header),
                BearerAuthentication(token: "downstream-bearer-token"),
            ])
            let config = A2AClientConfiguration(baseURL: baseURL)
                .with(authenticationProvider: composite)
            describe(config)
            print("    composes : APIKey(header) + Bearer")
        }

        // 8. From an AgentCard — let the spec drive the auth choice.
        section("8. Picking auth from AgentCard.securitySchemes")
        do {
            let card = AgentCard(
                name: "Sample Agent",
                description: "Advertises bearer + API key support.",
                supportedInterfaces: [
                    AgentInterface(
                        url: baseURL.absoluteString,
                        protocolBinding: AgentInterface.httpJSON,
                        protocolVersion: "1.0"
                    )
                ],
                version: "1.0",
                capabilities: AgentCapabilities(streaming: true),
                securitySchemes: [
                    "bearer": SecurityScheme(type: .http, scheme: "bearer", bearerFormat: "JWT"),
                    "apiKey": SecurityScheme(type: .apiKey, name: "X-API-Key", in: .header),
                ]
            )

            // We pick a scheme — bearer in this case — and build a
            // configuration straight off the card. The SDK validates
            // the protocol version and binding at this point.
            do {
                let config = try A2AClientConfiguration.from(
                    agentCard: card,
                    authenticationProvider: BearerAuthentication(token: "from-card-token")
                )
                describe(config)
                print("    derived  : binding=\(config.transportBinding.rawValue) version=\(config.protocolVersion)")
            } catch {
                print("    error    : \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    /// Prints a section header. Underlining is purely cosmetic.
    static func section(_ title: String) {
        print()
        print(title)
        print(String(repeating: "-", count: title.count))
    }

    /// Prints a one-line summary of the auth provider attached to a
    /// configuration. We do a runtime type check rather than asking
    /// providers to identify themselves so the helper still works for
    /// unknown custom implementations.
    static func describe(_ config: A2AClientConfiguration, label: String? = nil) {
        let prefix = label.map { "\($0): " } ?? ""
        guard let provider = config.authenticationProvider else {
            print("    \(prefix)NoAuthentication (default)")
            return
        }

        let kind: String
        if provider is NoAuthentication {
            kind = "NoAuthentication"
        } else if provider is APIKeyAuthentication {
            kind = "APIKeyAuthentication"
        } else if provider is BearerAuthentication {
            kind = "BearerAuthentication"
        } else if provider is BasicAuthentication {
            kind = "BasicAuthentication"
        } else if provider is OAuth2Authentication {
            kind = "OAuth2Authentication"
        } else if provider is CompositeAuthentication {
            kind = "CompositeAuthentication"
        } else {
            kind = "Custom (\(String(describing: type(of: provider))))"
        }
        print("    \(prefix)\(kind)")
    }
}

// MARK: - Custom Provider Example

/// A toy custom provider that signs each request with a header pair.
/// Real implementations should use `CryptoKit`/`CommonCrypto` — this
/// stub just demonstrates the protocol surface.
struct HMACSigner: AuthenticationProvider {
    let keyId: String
    let secret: Data

    func authenticate(request: URLRequest) async throws -> URLRequest {
        var request = request
        // Pretend to compute an HMAC signature for the request body.
        let signature = "stub-hmac-of-\(request.url?.path ?? "")"
        request.setValue(keyId, forHTTPHeaderField: "X-Signature-KeyId")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        return request
    }
}
