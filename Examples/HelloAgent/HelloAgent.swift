// HelloAgent.swift
// A2AClient Example
//
// The simplest possible A2A client — a "Hello, world!" for the A2A protocol 1.0.
//
// What this sample shows
// ----------------------
// • Creating an `A2AClient` from a base URL.
// • Sending a single text message with the convenience overload.
// • Handling both possible response shapes: an immediate `Message` reply
//   or a long-running `A2ATask`.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • The unified `SendMessageResponse` enum (`.message` | `.task`).
// • The default `HTTP+JSON` (REST) transport binding introduced in 1.0.
// • Friendly text-content extraction via `Message.textContent` and
//   `Artifact.textContent` (works regardless of how the agent split its
//   reply across `Part`s).
//
// Running the sample
// ------------------
// This file is part of the `HelloAgent` executable target declared in
// `Package.swift`. To run it against a real agent:
//
//     export A2A_AGENT_URL="https://your-a2a-agent.example.com"
//     swift run HelloAgent
//
// If `A2A_AGENT_URL` is not set the sample falls back to a placeholder so
// that the build still passes — the network call will of course fail
// without a live agent on the other end.

import A2AClient
import Foundation

@main
struct HelloAgent {
    static func main() async {
        // 1. Pick a base URL. In production you would point this at a
        //    real A2A 1.0 agent. We read it from the environment so that
        //    the same binary works against any deployment.
        let urlString = ProcessInfo.processInfo.environment["A2A_AGENT_URL"]
            ?? "https://agent.example.com"

        guard let baseURL = URL(string: urlString) else {
            print("HelloAgent: invalid URL \"\(urlString)\"")
            return
        }

        // 2. Create the client. `A2AClient(baseURL:)` uses the library
        //    defaults — HTTP+JSON transport, protocol version 1.0,
        //    camelCase JSON keys, and a 60 second request timeout.
        //
        //    For more control use `A2AClientConfiguration` and pass it
        //    to `A2AClient(configuration:)` — see the AuthShowcase sample.
        let client = A2AClient(baseURL: baseURL)

        print("HelloAgent → \(baseURL.absoluteString)")
        print("Library version: \(A2AClientVersion.version)")
        print("Protocol version: \(A2AClientVersion.protocolVersion)")
        print("---")

        do {
            // 3. Send a single text message. The string overload wraps
            //    the text in a `Message` with `role = .user` and a
            //    single `Part.text` for you.
            let response = try await client.sendMessage("Hello, agent!")

            // 4. The agent can answer in one of two ways. A short prompt
            //    typically returns an immediate `Message`; long-running
            //    work returns an `A2ATask` you can poll, subscribe to,
            //    or cancel.
            switch response {
            case .message(let message):
                // Immediate reply. `textContent` joins all text parts.
                print("Agent said: \(message.textContent)")

            case .task(let task):
                // The agent created a task — print the initial state and
                // any artifacts that were already attached.
                print("Agent created task \(task.id) in state \(task.state.rawValue)")
                if let artifacts = task.artifacts, !artifacts.isEmpty {
                    for artifact in artifacts {
                        print("  artifact: \(artifact.name ?? artifact.artifactId)")
                        print("  content : \(artifact.textContent)")
                    }
                }
                if task.isComplete {
                    print("Task is already in a terminal state.")
                } else {
                    print("Task is still running — see TaskLifecycleDemo for polling/streaming.")
                }
            }
        } catch let error as A2AError {
            // A2AError surfaces typed protocol errors (task not found,
            // auth required, version mismatch, etc.).
            print("A2A error: \(error.localizedDescription)")
        } catch {
            // Network or decoding errors fall through here.
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
}
