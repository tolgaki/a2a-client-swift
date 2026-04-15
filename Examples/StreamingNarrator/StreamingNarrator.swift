// StreamingNarrator.swift
// A2AClient Example
//
// Streams a long-running response from an A2A 1.0 agent and prints every
// event as it arrives. Models the canonical "story-generator" or
// "code-generator" UX where the agent streams artifact chunks as it works.
//
// What this sample shows
// ----------------------
// • `sendStreamingMessage(_:)` and `for try await event in stream`.
// • Handling all four cases of `StreamingEvent`:
//     - `.taskStatusUpdate` for lifecycle transitions (submitted → working
//       → completed).
//     - `.taskArtifactUpdate` for incremental artifact deliveries.
//     - `.task` for full task snapshots (some servers send these once
//       work is finished).
//     - `.message` for in-band agent messages outside the task lifecycle.
// • Stitching streamed artifact chunks together using `append` /
//   `lastChunk` semantics from `TaskArtifactUpdateEvent`.
// • Re-subscribing to a task with `subscribeToTask(_:)` if the connection
//   drops mid-stream.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • The Server-Sent Events (SSE) wire format normalized in 1.0.
// • The new `final` flag on `TaskStatusUpdateEvent` that lets clients
//   stop iterating once the server tells them the stream is done.
// • The `append` / `lastChunk` pair on `TaskArtifactUpdateEvent` for
//   chunk-by-chunk artifact assembly — critical for token-by-token
//   streaming from LLM agents.
//
// Running the sample
// ------------------
//     export A2A_AGENT_URL="https://your-streaming-agent.example.com"
//     export A2A_PROMPT="Write a short story about a Swift programmer."
//     swift run StreamingNarrator
//
// The agent must advertise `capabilities.streaming = true` in its
// AgentCard. If you don't have a streaming agent handy, run the
// `TaskLifecycleDemo` sample instead — it uses polling.

import A2AClient
import Foundation

@main
struct StreamingNarrator {
    static func main() async {
        let urlString = ProcessInfo.processInfo.environment["A2A_AGENT_URL"]
            ?? "https://agent.example.com"
        let prompt = ProcessInfo.processInfo.environment["A2A_PROMPT"]
            ?? "Tell me a short, vivid story about a developer who discovers they can talk to other AI agents."

        guard let baseURL = URL(string: urlString) else {
            print("StreamingNarrator: invalid URL \"\(urlString)\"")
            return
        }

        let client = A2AClient(baseURL: baseURL)
        print("StreamingNarrator → \(baseURL.absoluteString)")
        print("Prompt: \(prompt)")
        print("---")

        // Per-artifact buffers keyed by `artifactId`. Streamed artifacts
        // are sent in chunks; the server uses `append = true` to mean
        // "concatenate this onto the previous chunk", and `lastChunk = true`
        // to signal the artifact is complete.
        var buffers: [String: String] = [:]

        do {
            let stream = try await client.sendStreamingMessage(prompt)
            buffers = try await consume(stream: stream, client: client)
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }

        // Print whatever we managed to buffer, even on partial failure.
        if !buffers.isEmpty {
            print()
            print("=== final assembled artifacts ===")
            for (id, text) in buffers {
                print("• \(id):")
                print(text)
            }
        }
    }

    /// Pulls events from a streaming sequence and prints/processes each one.
    /// Returns the assembled artifact buffers keyed by `artifactId`.
    static func consume(
        stream: AsyncThrowingStream<StreamingEvent, Error>,
        client: A2AClient
    ) async throws -> [String: String] {
        var buffers: [String: String] = [:]
        var lastTaskId: String?

        for try await event in stream {
            switch event {

            case .taskStatusUpdate(let update):
                // Lifecycle transition — print the new state, optional
                // status message, and whether this is the final event.
                lastTaskId = update.taskId
                let stamp = update.status.timestamp ?? "—"
                let finalMarker = update.final == true ? " (FINAL)" : ""
                print("[status] \(update.status.state.rawValue) @ \(stamp)\(finalMarker)")

                if let statusMessage = update.status.message?.textContent,
                   !statusMessage.isEmpty {
                    print("         message: \(statusMessage)")
                }

                if update.status.state == .failed {
                    let reason = update.status.message?.textContent ?? "unknown"
                    print("[error]  task failed: \(reason)")
                }

            case .taskArtifactUpdate(let update):
                // Chunked artifact delivery. `append` controls whether
                // this is a new artifact or a continuation; `lastChunk`
                // tells us we have the complete payload.
                lastTaskId = update.taskId
                let chunk = update.artifact.textContent
                let id = update.artifact.artifactId
                let isAppend = update.append == true
                let isLast = update.lastChunk == true

                if isAppend {
                    buffers[id, default: ""] += chunk
                } else {
                    buffers[id] = chunk
                }

                let label = update.artifact.name ?? id
                let suffix = isLast ? " (last chunk)" : ""
                print("[chunk]  \(label) +\(chunk.count) chars\(suffix)")

            case .task(let task):
                // A full snapshot of the task — usually sent at the end.
                lastTaskId = task.id
                print("[task]   id=\(task.id) state=\(task.state.rawValue)")

                // Capture any artifacts the server attached to the snapshot.
                if let artifacts = task.artifacts {
                    for artifact in artifacts {
                        buffers[artifact.artifactId] = artifact.textContent
                    }
                }

            case .message(let message):
                // In-band agent message — for example a clarifying note
                // sent without binding it to a specific task lifecycle.
                print("[say]    \(message.textContent)")
            }
        }

        if let id = lastTaskId {
            print("---")
            print("stream complete (last task id: \(id))")
            // To reconnect to the same task after a disconnect:
            //
            //   let resumed = try await client.subscribeToTask(id)
            //   buffers = try await consume(stream: resumed, client: client)
            _ = client
        }

        return buffers
    }
}
