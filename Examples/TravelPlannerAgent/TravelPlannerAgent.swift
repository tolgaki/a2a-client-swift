// TravelPlannerAgent.swift
// A2AClient Example
//
// Demonstrates an on-device agent orchestrating work with remote A2A agents.
// Scenario: User asks "Plan a trip to Tokyo" and the orchestrator discovers
// flights, hotels, and weather agents, delegates in parallel, and aggregates results.
//
// This example uses only the public A2AClient API — no mocks or test imports.
// It won't run without real A2A agents, but it compiles and shows every major pattern.

import A2AClient
import Foundation

// MARK: - Domain Types

/// Pairs an AgentCard with a ready-to-use A2AClient for convenience.
struct RemoteAgent: Sendable {
    let card: AgentCard
    let client: A2AClient

    /// Whether this agent advertises a skill matching any of the given tags.
    func hasSkill(taggedWith tags: Set<String>) -> Bool {
        card.skills.contains { skill in
            !tags.isDisjoint(with: skill.tags)
        }
    }

    /// Whether this agent supports streaming responses.
    var supportsStreaming: Bool {
        card.capabilities.streaming == true
    }
}

/// Aggregated travel plan returned to the user.
struct TravelPlan: Sendable {
    var flights: String = "No flight info available"
    var hotel: String = "No hotel info available"
    var weather: String = "No weather info available"
}

/// Domain-specific errors for the orchestrator.
enum OrchestratorError: Error, LocalizedError {
    case noAgentFound(skill: String)
    case unexpectedResponse(detail: String)
    case taskFailed(taskId: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .noAgentFound(let skill):
            return "No agent found for skill: \(skill)"
        case .unexpectedResponse(let detail):
            return "Unexpected response: \(detail)"
        case .taskFailed(let taskId, let reason):
            return "Task \(taskId) failed: \(reason)"
        }
    }
}

// MARK: - OnDeviceAgent (Orchestrator)

/// An on-device orchestrator that discovers remote A2A agents, routes requests
/// based on skill tags, and aggregates results into a TravelPlan.
struct OnDeviceAgent: Sendable {
    /// Domains where we expect to find A2A agents via well-known discovery.
    let agentDomains: [String]

    init(agentDomains: [String] = ["flights.example.com", "hotels.example.com", "weather.example.com"]) {
        self.agentDomains = agentDomains
    }

    // MARK: - Agent Discovery

    /// Discovers agents from all configured domains.
    /// Agents that fail discovery are skipped gracefully.
    func discoverAgents() async -> [RemoteAgent] {
        var agents: [RemoteAgent] = []

        for domain in agentDomains {
            do {
                let (card, client) = try await A2A.discover(domain: domain)
                agents.append(RemoteAgent(card: card, client: client))
                print("Discovered agent: \(card.name) (\(card.skills.count) skills)")

                // Inspect capabilities
                if card.capabilities.streaming == true {
                    print("  - Supports streaming")
                }
                for skill in card.skills {
                    print("  - Skill: \(skill.name) [tags: \(skill.tags.joined(separator: ", "))]")
                }
            } catch {
                // Graceful degradation — skip agents that are unavailable
                print("Could not discover agent at \(domain): \(error.localizedDescription)")
            }
        }

        return agents
    }

    // MARK: - Weather Check (Blocking Request)

    /// Checks weather using a blocking sendMessage call.
    /// Demonstrates: `sendMessage(_:configuration:)` with `MessageSendConfiguration(blocking: true)`
    /// and handling `SendMessageResponse.message`.
    func checkWeather(destination: String, using agent: RemoteAgent) async throws -> String {
        let config = MessageSendConfiguration(blocking: true)
        let response = try await agent.client.sendMessage(
            "What is the weather forecast for \(destination) next week?",
            configuration: config
        )

        switch response {
        case .message(let message):
            // Immediate response — agent returned a Message directly
            return message.textContent

        case .task(let task):
            // Even with blocking: true, some agents return a completed Task
            if task.isComplete, let message = task.status.message {
                return message.textContent
            }
            return task.artifacts?.first?.textContent ?? "Weather data received (task \(task.id))"
        }
    }

    // MARK: - Flight Search via Streaming

    /// Searches for flights using streaming.
    /// Demonstrates: `sendStreamingMessage(_:)` → `for try await event in stream`
    /// handling all 4 StreamingEvent cases.
    func searchFlights(destination: String, using agent: RemoteAgent) async throws -> String {
        let stream = try await agent.client.sendStreamingMessage(
            "Find flights to \(destination) departing next Monday, returning Friday"
        )

        var flightResults = ""
        var lastTaskId: String?

        for try await event in stream {
            switch event {
            case .taskStatusUpdate(let update):
                lastTaskId = update.taskId
                print("Flight search status: \(update.status.state.rawValue)")

                if update.status.state == .failed {
                    let reason = update.status.message?.textContent ?? "unknown"
                    throw OrchestratorError.taskFailed(taskId: update.taskId, reason: reason)
                }

            case .taskArtifactUpdate(let update):
                // Accumulate artifact text as it streams in
                let chunk = update.artifact.textContent
                flightResults += chunk
                print("Flight result chunk: \(chunk.prefix(80))...")

            case .task(let task):
                // Final task snapshot
                lastTaskId = task.id
                if let artifacts = task.artifacts {
                    flightResults = artifacts.map(\.textContent).joined(separator: "\n")
                }

            case .message(let message):
                flightResults = message.textContent
            }
        }

        if flightResults.isEmpty {
            return "Flight search completed (task \(lastTaskId ?? "unknown")) — no results"
        }
        return flightResults
    }

    // MARK: - Flight Search via Polling (Fallback)

    /// Searches for flights using getTask polling — used when the agent doesn't support streaming.
    /// Demonstrates: `sendMessage` then `getTask` loop with `isComplete`/`needsInput` checks.
    func searchFlightsBlocking(destination: String, using agent: RemoteAgent) async throws -> String {
        let response = try await agent.client.sendMessage(
            "Find flights to \(destination) departing next Monday, returning Friday"
        )

        guard let task = response.task else {
            // Agent returned an immediate Message
            if let message = response.message {
                return message.textContent
            }
            throw OrchestratorError.unexpectedResponse(detail: "Expected a task or message")
        }

        // Poll until completion
        var current = task
        while !current.isComplete && !current.needsInput {
            // Simple backoff
            try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            current = try await agent.client.getTask(current.id)
            print("Polling flight task \(current.id): \(current.state.rawValue)")
        }

        if current.state == .failed {
            let reason = current.status.message?.textContent ?? "unknown"
            throw OrchestratorError.taskFailed(taskId: current.id, reason: reason)
        }

        return current.artifacts?.first?.textContent ?? current.status.message?.textContent ?? "Flight search completed"
    }

    // MARK: - Hotel Booking (Multi-turn Conversation)

    /// Books a hotel using multi-turn conversation with contextId and taskId.
    /// Demonstrates: handling `inputRequired` state across multiple turns.
    func bookHotel(destination: String, using agent: RemoteAgent) async throws -> String {
        let contextId = UUID().uuidString

        // Turn 1: Initial request
        var response = try await agent.client.sendMessage(
            "Find hotels in \(destination) for next Monday to Friday, 2 guests",
            contextId: contextId
        )

        // If the agent needs more input (e.g., price range, preferences), keep conversing
        var turnCount = 0
        let maxTurns = 5

        while let task = response.task, task.needsInput, turnCount < maxTurns {
            turnCount += 1

            // Read the agent's question from the status message
            let agentQuestion = task.status.message?.textContent ?? "Please provide more details"
            print("Hotel agent asks (turn \(turnCount)): \(agentQuestion)")

            // Simulate user providing follow-up info
            let followUp: String
            switch turnCount {
            case 1: followUp = "Budget is $200-300 per night, prefer 4-star hotels"
            case 2: followUp = "Yes, confirm that booking please"
            default: followUp = "Yes"
            }

            // Continue the conversation using the same contextId and taskId
            response = try await agent.client.sendMessage(
                followUp,
                contextId: contextId,
                taskId: task.id
            )
        }

        // Extract final result
        switch response {
        case .message(let message):
            return message.textContent
        case .task(let task):
            if task.state == .failed {
                let reason = task.status.message?.textContent ?? "unknown"
                throw OrchestratorError.taskFailed(taskId: task.id, reason: reason)
            }
            return task.artifacts?.first?.textContent ?? task.status.message?.textContent ?? "Hotel booked"
        }
    }

    // MARK: - Plan Trip (Concurrent Orchestration)

    /// Orchestrates all three agents in parallel using a task group.
    /// Demonstrates: `withTaskGroup` collecting `(String, String)` tuples
    /// for Swift 6 Sendable safety (no shared mutable state).
    func planTrip(to destination: String) async throws -> TravelPlan {
        let agents = await discoverAgents()

        // Find agents by skill tags
        let weatherAgent = agents.first { $0.hasSkill(taggedWith: ["weather", "forecast"]) }
        let flightsAgent = agents.first { $0.hasSkill(taggedWith: ["flights", "travel", "booking"]) }
        let hotelAgent = agents.first { $0.hasSkill(taggedWith: ["hotels", "accommodation", "booking"]) }

        // Dispatch to all available agents concurrently
        let results = try await withThrowingTaskGroup(
            of: (String, String).self,
            returning: [String: String].self
        ) { group in
            if let agent = weatherAgent {
                group.addTask {
                    let result = try await self.checkWeather(destination: destination, using: agent)
                    return ("weather", result)
                }
            }

            if let agent = flightsAgent {
                group.addTask {
                    // Use streaming if the agent supports it, otherwise poll
                    let result: String
                    if agent.supportsStreaming {
                        result = try await self.searchFlights(destination: destination, using: agent)
                    } else {
                        result = try await self.searchFlightsBlocking(destination: destination, using: agent)
                    }
                    return ("flights", result)
                }
            }

            if let agent = hotelAgent {
                group.addTask {
                    let result = try await self.bookHotel(destination: destination, using: agent)
                    return ("hotel", result)
                }
            }

            // Collect results — no shared mutable state
            var collected: [String: String] = [:]
            for try await (key, value) in group {
                collected[key] = value
            }
            return collected
        }

        // Assemble the travel plan
        var plan = TravelPlan()
        if let weather = results["weather"] { plan.weather = weather }
        if let flights = results["flights"] { plan.flights = flights }
        if let hotel = results["hotel"] { plan.hotel = hotel }

        return plan
    }
}

// MARK: - Entry Point

@main
struct TravelPlannerApp {
    static func main() async {
        print("=== A2A Travel Planner Agent ===\n")

        let orchestrator = OnDeviceAgent(agentDomains: [
            "flights.example.com",
            "hotels.example.com",
            "weather.example.com",
        ])

        do {
            let plan = try await orchestrator.planTrip(to: "Tokyo")

            print("\n=== Travel Plan for Tokyo ===")
            print("Weather:  \(plan.weather)")
            print("Flights:  \(plan.flights)")
            print("Hotel:    \(plan.hotel)")
            print("=============================")
        } catch let error as OrchestratorError {
            print("Orchestrator error: \(error.localizedDescription)")
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
}
