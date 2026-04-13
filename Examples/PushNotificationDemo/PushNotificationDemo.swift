// PushNotificationDemo.swift
// A2AClient Example
//
// Walks through the full push-notification configuration lifecycle for an
// A2A 1.0 task: create, list, get, delete. Push notifications let an
// agent deliver task updates to a webhook of yours instead of forcing
// the client to keep an open SSE stream or poll forever.
//
// What this sample shows
// ----------------------
// • Inspecting `AgentCard.capabilities.pushNotifications` to fail fast
//   when the agent doesn't support webhooks.
// • Creating a push-notification config for a task with
//   `createPushNotificationConfig(taskId:config:)`.
// • Authenticating the webhook callbacks with both `Bearer` and `Basic`
//   schemes via the `AuthenticationInfo` helpers.
// • Listing configs (`listPushNotificationConfigs(taskId:)`), reading a
//   single one (`getPushNotificationConfig(taskId:configId:)`), and
//   deleting it (`deletePushNotificationConfig(taskId:configId:)`).
// • Replacing the deprecated `setPushNotificationConfig` with the new
//   create/get/list/delete API.
//
// A2A protocol 1.0 highlights demonstrated
// ----------------------------------------
// • The 1.0 spec replaces the single `set` operation with a CRUD set so
//   a task can have *multiple* webhook configurations (think: one for
//   the user's email service and one for an internal Slack bridge).
// • `TaskPushNotificationConfig.id` is now required — the server
//   assigns it on create and you use it for subsequent get/delete
//   operations.
// • `AuthenticationInfo` follows the IANA HTTP Authentication scheme
//   names so server implementations can dispatch on the same registry
//   they already use for inbound requests.
//
// Running the sample
// ------------------
//     export A2A_AGENT_URL="https://your-a2a-agent.example.com"
//     export A2A_WEBHOOK_URL="https://your-app.example.com/a2a-webhook"
//     swift run PushNotificationDemo

import A2AClient
import Foundation

@main
struct PushNotificationDemo {
    static func main() async {
        let urlString = ProcessInfo.processInfo.environment["A2A_AGENT_URL"]
            ?? "https://agent.example.com"
        let webhook = ProcessInfo.processInfo.environment["A2A_WEBHOOK_URL"]
            ?? "https://your-app.example.com/a2a-webhook"

        guard let baseURL = URL(string: urlString) else {
            print("PushNotificationDemo: invalid URL \"\(urlString)\"")
            return
        }

        let client = A2AClient(baseURL: baseURL)
        print("PushNotificationDemo → \(baseURL.absoluteString)")
        print("Webhook target       → \(webhook)")
        print("==============================================")

        do {
            try await runLifecycle(client: client, webhook: webhook)
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }

    static func runLifecycle(client: A2AClient, webhook: String) async throws {
        // ─────────────────────────────────────────────────────────────
        // 1. Create a task we can attach a webhook to.
        // ─────────────────────────────────────────────────────────────
        // Push notifications are scoped to a task — without a task id
        // there is nothing to subscribe to. We open a long-running
        // task using `returnImmediately = true` so the demo never
        // blocks on completion.
        print("[1] creating a task")
        let response = try await client.sendMessage(
            "Generate a long-running report I can monitor via webhook.",
            configuration: MessageSendConfiguration(returnImmediately: true)
        )
        guard let task = response.task else {
            print("    server returned a Message — push notifications need a task")
            return
        }
        print("    task id=\(task.id) state=\(task.state.rawValue)")

        // ─────────────────────────────────────────────────────────────
        // 2. Build the webhook config.
        // ─────────────────────────────────────────────────────────────
        // The agent will POST a `TaskStatusUpdateEvent` payload to our
        // webhook URL whenever the task transitions. We give it a
        // shared verification token so we can ignore spoofed callbacks.
        print()
        print("[2] creating a push notification config")
        let primaryConfig = PushNotificationConfig(
            url: webhook,
            token: "shared-verification-token",
            authentication: .bearer("agent-side-bearer")
        )

        let primary = try await client.createPushNotificationConfig(
            taskId: task.id,
            config: primaryConfig
        )
        print("    created config id=\(primary.id) → \(primary.pushNotificationConfig.url)")

        // ─────────────────────────────────────────────────────────────
        // 3. Add a second config — the spec allows multiple per task.
        // ─────────────────────────────────────────────────────────────
        // For instance: one webhook for the user's notification service
        // and another for an internal observability pipeline.
        print()
        print("[3] adding a second config (Basic auth)")
        let secondaryConfig = PushNotificationConfig(
            url: webhook + "/observability",
            token: "obs-verification-token",
            authentication: .basic(username: "telemetry", password: "rotate-me")
        )
        let secondary = try await client.createPushNotificationConfig(
            taskId: task.id,
            config: secondaryConfig
        )
        print("    created config id=\(secondary.id) → \(secondary.pushNotificationConfig.url)")

        // ─────────────────────────────────────────────────────────────
        // 4. List all configs attached to the task.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[4] listing configs")
        let configs = try await client.listPushNotificationConfigs(taskId: task.id)
        print("    \(configs.count) config(s) registered:")
        for c in configs {
            let scheme = c.pushNotificationConfig.authentication?.scheme ?? "none"
            print("      • id=\(c.id) auth=\(scheme) url=\(c.pushNotificationConfig.url)")
        }

        // ─────────────────────────────────────────────────────────────
        // 5. Fetch one config by id.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[5] fetching config \(primary.id) by id")
        let fetched = try await client.getPushNotificationConfig(
            taskId: task.id,
            configId: primary.id
        )
        print("    url   : \(fetched.pushNotificationConfig.url)")
        print("    token : \(fetched.pushNotificationConfig.token ?? "—")")
        print("    auth  : \(fetched.pushNotificationConfig.authentication?.scheme ?? "none")")

        // ─────────────────────────────────────────────────────────────
        // 6. Delete the secondary config.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[6] deleting config \(secondary.id)")
        try await client.deletePushNotificationConfig(
            taskId: task.id,
            configId: secondary.id
        )
        print("    deleted.")

        // ─────────────────────────────────────────────────────────────
        // 7. Verify the deletion.
        // ─────────────────────────────────────────────────────────────
        print()
        print("[7] re-listing after delete")
        let remaining = try await client.listPushNotificationConfigs(taskId: task.id)
        print("    \(remaining.count) config(s) remain")
        for c in remaining {
            print("      • id=\(c.id) url=\(c.pushNotificationConfig.url)")
        }

        // Reminder for users coming from older SDK versions.
        print()
        print("Note: setPushNotificationConfig(...) is deprecated in 1.0.")
        print("      Use createPushNotificationConfig(...) instead.")
    }
}
