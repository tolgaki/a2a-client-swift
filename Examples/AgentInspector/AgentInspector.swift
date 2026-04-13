// AgentInspector.swift
// A2AClient Example
//
// Discovers an A2A agent and pretty-prints every metadata field exposed by
// the v1.0 Agent Card. Useful as a debugging tool when integrating with a
// new agent and as a tour of the `AgentCard` API surface.
//
// What this sample shows
// ----------------------
// • Well-known agent discovery via `A2A.discover(domain:)`.
// • Every public field on `AgentCard`, `AgentInterface`, `AgentProvider`,
//   `AgentCapabilities`, `AgentExtension`, `AgentSkill`, `SecurityScheme`,
//   `SecurityRequirement`, and `AgentCardSignature`.
// • Reading the multi-interface array introduced in 1.0 (the legacy
//   `url`/`protocolVersion` accessors still work, but the new
//   `supportedInterfaces` array is the canonical source).
// • Inspecting capability flags so the caller can decide whether to use
//   streaming, push notifications, or extended cards.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • `supportedInterfaces` array — agents can now expose multiple bindings
//   (HTTP+JSON, JSONRPC, GRPC) at different URLs.
// • `extendedAgentCard` capability flag — clients with credentials may
//   call `getExtendedAgentCard()` to fetch a richer card.
// • `securitySchemes` / `securityRequirements` — OpenAPI-style auth
//   advertisement so clients can pick the right credential type.
// • Skill-level `securityRequirements` and `inputModes`/`outputModes` —
//   per-skill auth and modality overrides.
// • `signatures` — JWS signatures over the card so callers can verify
//   that the agent is who it claims to be.
//
// Running the sample
// ------------------
//     export A2A_AGENT_DOMAIN="agent.example.com"
//     swift run AgentInspector
//
// If the domain is unreachable the sample prints the underlying error
// rather than crashing — this is intentional so the binary is also useful
// as a "did discovery work?" smoke test.

import A2AClient
import Foundation

@main
struct AgentInspector {
    static func main() async {
        let domain = ProcessInfo.processInfo.environment["A2A_AGENT_DOMAIN"]
            ?? "agent.example.com"

        print("AgentInspector → \(domain)")
        print("===================================================")

        do {
            // `A2A.discover(domain:)` builds the well-known URL
            // (https://<domain>/.well-known/agent-card.json), fetches the
            // card, and constructs a ready-to-use `A2AClient` from the
            // first interface declared by the card. The legacy v0.3
            // path (`/agent.json`) is automatically tried as a fallback.
            let (card, client) = try await A2A.discover(domain: domain)

            print(renderCard(card))

            // If the agent supports it, fetch the authenticated extended
            // card. This is a no-op for most public agents.
            if card.capabilities.extendedAgentCard == true {
                print()
                print("Extended agent card support advertised — fetching…")
                do {
                    let extended = try await client.getExtendedAgentCard()
                    print(renderCard(extended, prefix: "extended card"))
                } catch {
                    print("(extended card fetch failed: \(error.localizedDescription))")
                }
            }
        } catch let error as A2AError {
            print("A2A discovery failed: \(error.localizedDescription)")
        } catch {
            print("Discovery failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Rendering

    /// Returns a human-readable representation of every field on an
    /// `AgentCard`. Intentionally written with print-by-print formatting
    /// rather than a recursive printer so the output is easy to scan.
    static func renderCard(_ card: AgentCard, prefix: String = "agent card") -> String {
        var lines: [String] = []
        lines.append("--- \(prefix) ---")
        lines.append("name        : \(card.name)")
        lines.append("description : \(card.description)")
        lines.append("version     : \(card.version)")

        if let icon = card.iconUrl {
            lines.append("iconUrl     : \(icon)")
        }
        if let docs = card.documentationUrl {
            lines.append("docs        : \(docs)")
        }

        if let provider = card.provider {
            lines.append("provider    : \(provider.organization) (\(provider.url))")
        }

        // 1.0 introduced `supportedInterfaces` — agents may expose more
        // than one transport binding (HTTP+JSON, JSONRPC, GRPC).
        lines.append("interfaces  : \(card.supportedInterfaces.count)")
        for (index, iface) in card.supportedInterfaces.enumerated() {
            let marker = index == 0 ? "★" : " "  // mark the preferred one
            lines.append("  \(marker) [\(index)] \(iface.protocolBinding) v\(iface.protocolVersion)")
            lines.append("       url    : \(iface.url)")
            if let tenant = iface.tenant {
                lines.append("       tenant : \(tenant)")
            }
        }

        // Capabilities tell the client which features the agent supports.
        let caps = card.capabilities
        lines.append("capabilities:")
        lines.append("  streaming             : \(format(caps.streaming))")
        lines.append("  pushNotifications     : \(format(caps.pushNotifications))")
        lines.append("  extendedAgentCard     : \(format(caps.extendedAgentCard))")
        if let extensions = caps.extensions, !extensions.isEmpty {
            lines.append("  extensions (\(extensions.count)):")
            for ext in extensions {
                let required = ext.required == true ? "required" : "optional"
                lines.append("    - \(ext.uri) [\(required)]")
                if let desc = ext.description {
                    lines.append("        \(desc)")
                }
            }
        }

        // Default modalities. Skills can override these.
        lines.append("defaultInput : \(card.defaultInputModes.joined(separator: ", "))")
        lines.append("defaultOutput: \(card.defaultOutputModes.joined(separator: ", "))")

        // Security schemes describe HOW to authenticate; security
        // requirements describe WHICH schemes are mandatory.
        if let schemes = card.securitySchemes, !schemes.isEmpty {
            lines.append("securitySchemes (\(schemes.count)):")
            for (name, scheme) in schemes.sorted(by: { $0.key < $1.key }) {
                lines.append("  - \(name) : \(scheme.type.rawValue)")
                if let desc = scheme.description {
                    lines.append("      \(desc)")
                }
            }
        }
        if let requirements = card.securityRequirements, !requirements.isEmpty {
            lines.append("securityRequirements (\(requirements.count)):")
            for req in requirements {
                for (scheme, scopes) in req.schemes {
                    lines.append("  - \(scheme) : [\(scopes.joined(separator: ", "))]")
                }
            }
        }

        // Skills are the user-visible "things this agent can do".
        if !card.skills.isEmpty {
            lines.append("skills (\(card.skills.count)):")
            for skill in card.skills {
                lines.append("  • \(skill.name) [\(skill.id)]")
                lines.append("      \(skill.description)")
                if !skill.tags.isEmpty {
                    lines.append("      tags    : \(skill.tags.joined(separator: ", "))")
                }
                if let examples = skill.examples, !examples.isEmpty {
                    lines.append("      examples:")
                    for example in examples {
                        lines.append("        - \(example)")
                    }
                }
                if let inputs = skill.inputModes {
                    lines.append("      inputs  : \(inputs.joined(separator: ", "))")
                }
                if let outputs = skill.outputModes {
                    lines.append("      outputs : \(outputs.joined(separator: ", "))")
                }
                if let reqs = skill.securityRequirements, !reqs.isEmpty {
                    lines.append("      auth    : \(reqs.count) requirement(s)")
                }
            }
        }

        // Signatures (JWS) give clients a way to verify card authenticity.
        if let signatures = card.signatures, !signatures.isEmpty {
            lines.append("signatures (\(signatures.count)):")
            for (i, sig) in signatures.enumerated() {
                lines.append("  [\(i)] protected: \(sig.protected.prefix(40))…")
                lines.append("       signature: \(sig.signature.prefix(40))…")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Formats an `Optional<Bool>` capability flag for display.
    static func format(_ flag: Bool?) -> String {
        guard let flag = flag else { return "unset" }
        return flag ? "true" : "false"
    }
}
