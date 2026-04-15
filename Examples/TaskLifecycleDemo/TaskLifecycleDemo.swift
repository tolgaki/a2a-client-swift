// TaskLifecycleDemo.swift
// A2AClient Example
//
// Walks an A2A 1.0 task through its full lifecycle: create, poll, list,
// inspect, cancel. Each phase prints what it did and what the SDK
// returned, so this sample doubles as a tour of the task-management API.
//
// What this sample shows
// ----------------------
// • `sendMessage(_:configuration:)` with `returnImmediately = true` to
//   create a task without blocking on completion.
// • `getTask(_:historyLength:)` for fetching the current state.
// • Polling loop with backoff and explicit terminal-state detection.
// • `listTasks(_:)` with rich `TaskQueryParams` filtering.
// • Filtering tasks by `contextId`, `status`, and `statusTimestampAfter`.
// • Pagination via `pageSize` / `pageToken`.
// • `cancelTask(_:)` and graceful handling of `taskNotCancelable`.
// • Reading the multi-turn `history` array from a task.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • The full set of v1.0 task operations are exposed as plain methods on
//   `A2AClient`. There are no separate request types to construct.
// • `TaskQueryParams` mirrors the spec's `tasks/list` query options
//   exactly, including the new `includeArtifacts` flag and
//   `statusTimestampAfter` filter that landed in 1.0.
// • `A2ATask.isComplete` and `A2ATask.needsInput` give you ergonomic
//   booleans rather than forcing a switch on every `TaskState` case.
//
// Running the sample
// ------------------
//     export A2A_AGENT_URL="https://your-a2a-agent.example.com"
//     swift run TaskLifecycleDemo

import A2AClient
import Foundation

@main
struct TaskLifecycleDemo {
    static func main() async {
        let urlString = ProcessInfo.processInfo.environment["A2A_AGENT_URL"]
            ?? "https://agent.example.com"

        guard let baseURL = URL(string: urlString) else {
            print("TaskLifecycleDemo: invalid URL \"\(urlString)\"")
            return
        }

        let client = A2AClient(baseURL: baseURL)
        print("TaskLifecycleDemo → \(baseURL.absoluteString)")
        print("============================================")

        do {
            try await runLifecycle(using: client)
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    static func runLifecycle(using client: A2AClient) async throws {
        let contextId = UUID().uuidString
        print("contextId: \(contextId)")
        print()

        // ─────────────────────────────────────────────────────────────
        // Phase 1 — Submit a task without blocking on completion.
        // ─────────────────────────────────────────────────────────────
        // `returnImmediately = true` tells the agent to register the
        // task and return as soon as possible. The default behavior is
        // the opposite: the server waits for a terminal state before
        // responding, which simplifies the synchronous case but blocks
        // the caller. For demos we want to see every transition.
        print("[1] submitting task")
        let submitConfig = MessageSendConfiguration(
            // Hint to the server which output we can render. Many agents
            // honor this when picking between text and rich data.
            acceptedOutputModes: ["text/plain", "application/json"],
            // Cap how much history we want back. nil means "server default".
            historyLength: 10,
            returnImmediately: true
        )
        let submitResponse = try await client.sendMessage(
            "Generate a 3-sentence summary of the A2A protocol 1.0 release.",
            contextId: contextId,
            configuration: submitConfig
        )

        guard let initialTask = submitResponse.task else {
            // Agents that do everything in <100 ms may answer with a
            // direct Message rather than opening a task. Handle that.
            if let message = submitResponse.message {
                print("    server returned an immediate message — no task to track")
                print("    \(message.textContent)")
            }
            return
        }
        print("    created task id=\(initialTask.id) state=\(initialTask.state.rawValue)")

        // ─────────────────────────────────────────────────────────────
        // Phase 2 — Poll until the task reaches a terminal state.
        // ─────────────────────────────────────────────────────────────
        // For agents that support streaming you'd subscribe instead —
        // see the StreamingNarrator example. Polling is the universal
        // fallback.
        print()
        print("[2] polling for completion")
        var current = initialTask
        var attempts = 0
        let maxAttempts = 20

        while !current.isComplete && !current.needsInput && attempts < maxAttempts {
            attempts += 1
            // Linear backoff capped at 5 s. Real apps should use a
            // jittered backoff and respect server hints.
            let delaySeconds = min(attempts, 5)
            try await _Concurrency.Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)

            // `getTask` is idempotent — call it as often as you need.
            // `historyLength: 0` skips the history blob to save bytes.
            current = try await client.getTask(current.id, historyLength: 0)
            print("    poll \(attempts): state=\(current.state.rawValue)")
        }

        if current.needsInput {
            print("    task is waiting for client input — not handled in this demo")
        }
        if !current.isComplete && !current.needsInput {
            print("    timed out waiting for completion (\(maxAttempts) attempts)")
        }

        // ─────────────────────────────────────────────────────────────
        // Phase 3 — Inspect the finished task.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[3] inspecting completed task")
        print("    final state : \(current.state.rawValue)")
        if let timestamp = current.status.timestamp {
            print("    timestamp   : \(timestamp)")
        }
        if let statusMsg = current.status.message?.textContent, !statusMsg.isEmpty {
            print("    status msg  : \(statusMsg)")
        }
        if let artifacts = current.artifacts, !artifacts.isEmpty {
            print("    artifacts   : \(artifacts.count)")
            for artifact in artifacts {
                let name = artifact.name ?? artifact.artifactId
                print("      • \(name) — \(artifact.textContent.prefix(80))")
            }
        }
        if let history = current.history, !history.isEmpty {
            print("    history     : \(history.count) message(s)")
            for message in history {
                print("      [\(message.role.rawValue)] \(message.textContent.prefix(60))")
            }
        }

        // ─────────────────────────────────────────────────────────────
        // Phase 4 — List tasks with rich filters.
        // ─────────────────────────────────────────────────────────────
        // `TaskQueryParams` exposes every server-side filter from the
        // 1.0 spec. We use most of them here.
        print()
        print("[4] listing tasks in this context")
        let listParams = TaskQueryParams(
            contextId: contextId,           // narrow to our conversation
            status: nil,                    // no state filter — any state OK
            pageSize: 20,
            pageToken: nil,                 // first page
            historyLength: 0,               // skip history for speed
            statusTimestampAfter: nil,      // no time floor
            includeArtifacts: false         // skip artifact bodies
        )
        let listing = try await client.listTasks(listParams)
        print("    total in context: \(listing.totalSize) (page size \(listing.pageSize))")
        for task in listing.tasks {
            print("      - \(task.id) [\(task.state.rawValue)]")
        }

        // The same call exposes a one-arg convenience overload:
        //   try await client.listTasks(contextId: contextId)
        // — useful when you don't need to tweak pageSize/etc.

        // ─────────────────────────────────────────────────────────────
        // Phase 5 — Submit a second task and cancel it.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[5] submitting a second task and cancelling it")
        let cancelTarget = try await client.sendMessage(
            "Render a long-running report so we can cancel it.",
            contextId: contextId,
            configuration: MessageSendConfiguration(returnImmediately: true)
        )
        guard let toCancel = cancelTarget.task else {
            print("    server didn't open a task — nothing to cancel")
            return
        }
        print("    created task id=\(toCancel.id)")

        // `cancelTask` returns the updated task snapshot. If the agent
        // refuses (because the task is already terminal, for instance)
        // we get a typed `taskNotCancelable` error.
        do {
            let cancelled = try await client.cancelTask(toCancel.id)
            print("    cancel result : state=\(cancelled.state.rawValue)")
        } catch A2AError.taskNotCancelable(let id, let state, let msg) {
            print("    cancel rejected: task \(id) is in state \(state.rawValue)")
            if let msg = msg { print("    server says: \(msg)") }
        }
    }
}
