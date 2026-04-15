// MultimodalMessenger.swift
// A2AClient Example
//
// Sends a single multi-part `Message` containing every kind of `Part`
// supported by A2A 1.0 — text, raw bytes (inline file), URL reference,
// and structured data — and then walks the response, demonstrating how
// to inspect each part type.
//
// What this sample shows
// ----------------------
// • Building a multi-part `Message` with `Message.user(parts:)`.
// • Every factory on `Part`: `.text`, `.raw` (inline file bytes),
//   `.url` (file by reference), `.data` (structured JSON).
// • Per-part metadata, filename, and media-type fields.
// • Walking the response's parts via the convenience properties
//   (`textParts`, `fileParts`, `dataParts`) and the `contentType` enum.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • The "oneof content" `Part` model — exactly one of `text`, `raw`,
//   `url`, `data` must be set per part. The library precondition-checks
//   this, and the encoder writes the matching `kind` discriminator.
// • Inline file bytes are base64-encoded automatically when serialized.
// • The `data` part type now accepts arbitrary `AnyCodable` values, not
//   just `[String: AnyCodable]` dictionaries — handy for sending arrays
//   or scalars when an agent expects structured input.
// • `referenceTaskIds` on `Message` for cross-referencing existing tasks
//   (useful when forwarding context from another conversation).
//
// Running the sample
// ------------------
//     export A2A_AGENT_URL="https://your-multimodal-agent.example.com"
//     swift run MultimodalMessenger

import A2AClient
import Foundation

@main
struct MultimodalMessenger {
    static func main() async {
        let urlString = ProcessInfo.processInfo.environment["A2A_AGENT_URL"]
            ?? "https://agent.example.com"

        guard let baseURL = URL(string: urlString) else {
            print("MultimodalMessenger: invalid URL \"\(urlString)\"")
            return
        }

        let client = A2AClient(baseURL: baseURL)
        print("MultimodalMessenger → \(baseURL.absoluteString)")
        print("---")

        // 1. Compose every kind of part.
        let parts: [Part] = [
            // Plain text. Media type defaults to "text/plain".
            .text("Please review the following inputs and produce a summary."),

            // A short label that we tag with custom metadata so the agent
            // can route it differently from the main instruction text.
            .text(
                "Treat the JSON payload as the source of truth.",
                metadata: ["role": AnyCodable("instruction")]
            ),

            // Inline raw file bytes. The library base64-encodes the bytes
            // when serializing to JSON. Use this for small attachments
            // (≲100 KB); use `.url(...)` for anything larger.
            .raw(
                Data("hello,world\n42,7\n".utf8),
                filename: "scratch.csv",
                mediaType: "text/csv"
            ),

            // External file reference. The agent fetches the URL itself,
            // so this works even for multi-megabyte assets.
            .url(
                "https://example.com/datasets/q4-report.pdf",
                filename: "q4-report.pdf",
                mediaType: "application/pdf"
            ),

            // Structured JSON payload. Pass any `[String: AnyCodable]`
            // map and the SDK serializes it under the `data` key.
            .data(
                [
                    "customer_id": AnyCodable(42),
                    "interests": AnyCodable(["swift", "agents", "protocol-design"]),
                    "premium": AnyCodable(true),
                ],
                metadata: ["schema": AnyCodable("v1.customer-profile")]
            ),
        ]

        // 2. Wrap the parts in a user `Message`. We attach a context id
        //    so a follow-up question can be sent in the same conversation,
        //    plus reference one fictional prior task id for context.
        let contextId = UUID().uuidString
        let message = Message(
            messageId: UUID().uuidString,
            role: .user,
            parts: parts,
            contextId: contextId,
            referenceTaskIds: ["earlier-task-12345"],
            metadata: ["client": AnyCodable("multimodal-messenger-sample")]
        )

        // 3. Send it. We don't pass a `MessageSendConfiguration` so the
        //    agent decides whether to return immediately or open a task.
        do {
            let response = try await client.sendMessage(message)
            describe(response)
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    // MARK: - Response Walker

    /// Prints every part of an agent reply, regardless of whether the reply
    /// arrives as a `Message` or as the artifacts of an `A2ATask`.
    static func describe(_ response: SendMessageResponse) {
        switch response {
        case .message(let message):
            print("agent → message (id=\(message.messageId), role=\(message.role.rawValue))")
            walkParts(message.parts)

        case .task(let task):
            print("agent → task (id=\(task.id), state=\(task.state.rawValue))")
            for artifact in task.artifacts ?? [] {
                print("artifact: \(artifact.name ?? artifact.artifactId)")
                walkParts(artifact.parts)
            }
        }
    }

    /// Demonstrates how to inspect each Part's content using the
    /// convenience flags and the `contentType` enum.
    static func walkParts(_ parts: [Part]) {
        for (index, part) in parts.enumerated() {
            print("  [\(index)] kind=\(part.contentType.rawValue) media=\(part.mediaType ?? "—")")

            switch part.contentType {
            case .text:
                let text = part.text ?? ""
                print("       text: \(preview(text))")

            case .raw:
                let bytes = part.raw?.count ?? 0
                let name = part.filename ?? "(unnamed)"
                print("       file: \(name) (\(bytes) bytes inline)")

            case .url:
                let target = part.url ?? "(no url)"
                let name = part.filename ?? "(unnamed)"
                print("       link: \(name) → \(target)")

            case .data:
                // `AnyCodable.value` exposes the decoded JSON value.
                if let dict = part.data?.value as? [String: Any] {
                    print("       data: \(dict.keys.sorted())")
                } else if let array = part.data?.value as? [Any] {
                    print("       data: array of \(array.count) item(s)")
                } else {
                    print("       data: \(String(describing: part.data?.value))")
                }

            case .unknown:
                print("       (no content — should never happen for valid parts)")
            }

            if let metadata = part.metadata, !metadata.isEmpty {
                print("       meta: \(metadata.keys.sorted())")
            }
        }
    }

    /// Helper to keep long text from blowing up the console.
    static func preview(_ text: String, limit: Int = 80) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "…"
    }
}
