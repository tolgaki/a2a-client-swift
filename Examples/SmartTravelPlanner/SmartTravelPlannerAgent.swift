// SmartTravelPlannerAgent.swift
// A2AClient Example
//
// Demonstrates an on-device agent using an LLM/NLU intent router to classify
// user intent, select remote A2A agents, and craft per-agent prompts.
//
// This builds on TravelPlannerAgent by replacing hardcoded tag matching with
// an IntentRouter protocol — the realistic pattern where an on-device model
// (like Apple Intelligence / Foundation Models) decides which agents to call
// and what to ask them.
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

/// Categories of travel-related tasks the router can assign.
enum AgentCategory: String, Sendable {
    case weather
    case flights
    case hotel
}

/// Pairs a remote agent with an LLM-crafted prompt and a category label.
/// The router produces these to tell the orchestrator exactly which agent
/// to call and what to ask it.
struct AgentAssignment: Sendable {
    /// The remote agent selected for this sub-task.
    let agent: RemoteAgent
    /// The category of the assignment (weather, flights, hotel).
    let category: AgentCategory
    /// An LLM-crafted prompt tailored to this specific agent's capabilities.
    let prompt: String
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
    case routingFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .noAgentFound(let skill):
            return "No agent found for skill: \(skill)"
        case .unexpectedResponse(let detail):
            return "Unexpected response: \(detail)"
        case .taskFailed(let taskId, let reason):
            return "Task \(taskId) failed: \(reason)"
        case .routingFailed(let detail):
            return "Intent routing failed: \(detail)"
        }
    }
}

// MARK: - Intent Router Protocol

/// An intent router classifies the user's natural language intent and selects
/// which agents to dispatch to, along with tailored prompts for each.
///
/// In production, this would call an on-device LLM (e.g. Apple Foundation Models)
/// or a cloud model to:
///   1. Parse the user's query into structured intents
///   2. Match intents to available agent capabilities
///   3. Craft optimized prompts for each selected agent
///
/// The protocol is `Sendable` so it can be used safely in concurrent contexts.
protocol IntentRouter: Sendable {
    /// Analyze the user's intent and return assignments for relevant agents.
    ///
    /// - Parameters:
    ///   - intent: The user's natural language query.
    ///   - agents: Available remote agents discovered via A2A protocol.
    /// - Returns: Agent assignments with crafted prompts, one per relevant agent.
    func route(intent: String, agents: [RemoteAgent]) async throws -> [AgentAssignment]
}

// MARK: - Simulated Intent Router

/// A simulated intent router that mimics what an LLM would do using keyword
/// matching and template-based prompt crafting.
///
/// **In a real implementation**, you would replace the body of `route(intent:agents:)`
/// with a call to your LLM of choice. For example:
///
/// ```swift
/// // Using Apple Foundation Models (iOS 26+):
/// let session = LanguageModelSession()
/// let schema = AgentAssignmentSchema(agents: agents)
/// let response = try await session.respond(
///     to: "Given these agents: \(agentDescriptions), route this query: \(intent)",
///     generating: schema
/// )
/// return response.assignments
///
/// // Using a cloud LLM:
/// let prompt = """
///     You are a travel planning router. Given these available agents:
///     \(agents.map { "- \($0.card.name): \($0.card.description)" }.joined(separator: "\n"))
///
///     Route this user query to the appropriate agents and craft a specific
///     prompt for each: "\(intent)"
///     """
/// let result = try await llmClient.complete(prompt)
/// return parseAssignments(from: result, agents: agents)
/// ```
///
/// This simulated version demonstrates the same input/output contract so you
/// can see how the orchestrator consumes router results.
struct SimulatedIntentRouter: IntentRouter {

    func route(intent: String, agents: [RemoteAgent]) async throws -> [AgentAssignment] {
        let lower = intent.lowercased()
        var assignments: [AgentAssignment] = []

        // --- Step 1: Extract entities from the query ---
        // A real LLM would parse: destination, dates, budget, preferences, etc.
        // Here we do naive keyword extraction as a stand-in.

        let destination = extractDestination(from: lower)
        let dates = extractDates(from: lower)
        let budget = extractBudget(from: lower)

        // --- Step 2: Determine which intents are present ---
        // A real LLM would classify intents (weather, flights, hotel, activities, etc.)
        // and could handle complex queries like "find me a warm destination with cheap flights"

        let wantsWeather = lower.contains("weather") || lower.contains("forecast")
            || lower.contains("temperature") || lower.contains("climate")
            || lower.contains("what's it like")
        let wantsFlights = lower.contains("flight") || lower.contains("fly")
            || lower.contains("travel") || lower.contains("get there")
        let wantsHotel = lower.contains("hotel") || lower.contains("stay")
            || lower.contains("accommodation") || lower.contains("book")
            || lower.contains("lodge") || lower.contains("room")

        // If the query is very general ("plan a trip to X"), enable all categories
        let isGeneralTripQuery = lower.contains("plan") || lower.contains("trip")
            || lower.contains("vacation") || lower.contains("visit")
        let enableAll = isGeneralTripQuery && !wantsWeather && !wantsFlights && !wantsHotel

        // --- Step 3: Match intents to agents and craft prompts ---
        // A real LLM would consider each agent's skill descriptions, not just tags,
        // and would craft prompts that leverage agent-specific capabilities.

        if wantsWeather || enableAll {
            if let agent = agents.first(where: { $0.hasSkill(taggedWith: ["weather", "forecast"]) }) {
                // Craft a prompt that includes extracted entities
                let prompt = craftWeatherPrompt(destination: destination, dates: dates)
                assignments.append(AgentAssignment(agent: agent, category: .weather, prompt: prompt))
            }
        }

        if wantsFlights || enableAll {
            if let agent = agents.first(where: { $0.hasSkill(taggedWith: ["flights", "travel", "booking"]) }) {
                let prompt = craftFlightsPrompt(destination: destination, dates: dates, budget: budget)
                assignments.append(AgentAssignment(agent: agent, category: .flights, prompt: prompt))
            }
        }

        if wantsHotel || enableAll {
            if let agent = agents.first(where: { $0.hasSkill(taggedWith: ["hotels", "accommodation", "booking"]) }) {
                let prompt = craftHotelPrompt(destination: destination, dates: dates, budget: budget)
                assignments.append(AgentAssignment(agent: agent, category: .hotel, prompt: prompt))
            }
        }

        return assignments
    }

    // MARK: - Entity Extraction (simulated)

    /// A real LLM would extract the destination as a structured entity.
    private func extractDestination(from text: String) -> String {
        // Naive: look for "to <place>" or "in <place>"
        let patterns = ["to ", "in ", "visit "]
        for pattern in patterns {
            if let range = text.range(of: pattern) {
                let after = text[range.upperBound...]
                let words = after.split(separator: " ").prefix(2)
                if !words.isEmpty {
                    return words.map { $0.capitalized }.joined(separator: " ")
                }
            }
        }
        return "the destination"
    }

    /// A real LLM would extract dates/duration as structured entities.
    private func extractDates(from text: String) -> String {
        // Look for month names or duration phrases
        let months = ["january", "february", "march", "april", "may", "june",
                      "july", "august", "september", "october", "november", "december"]
        for month in months {
            if text.contains(month) { return month.capitalized }
        }
        if text.contains("week") { return "one week" }
        if text.contains("weekend") { return "this weekend" }
        return "next week"
    }

    /// A real LLM would extract budget constraints as structured entities.
    private func extractBudget(from text: String) -> String? {
        // Look for dollar amounts
        if let range = text.range(of: #"\$\d+"#, options: .regularExpression) {
            return String(text[range])
        }
        if text.contains("cheap") || text.contains("budget") { return "budget-friendly" }
        if text.contains("luxury") || text.contains("premium") { return "luxury" }
        return nil
    }

    // MARK: - Prompt Crafting (simulated)

    /// Crafts a weather-specific prompt. A real LLM would consider the agent's
    /// specific capabilities (hourly vs daily forecast, historical data, etc.)
    private func craftWeatherPrompt(destination: String, dates: String) -> String {
        "What is the weather forecast for \(destination) during \(dates)? " +
        "Include daily highs/lows and precipitation chances."
    }

    /// Crafts a flights-specific prompt with budget awareness.
    private func craftFlightsPrompt(destination: String, dates: String, budget: String?) -> String {
        var prompt = "Find flights to \(destination) for \(dates). "
        if let budget = budget {
            prompt += "Budget preference: \(budget). "
        }
        prompt += "Show the top options sorted by best value."
        return prompt
    }

    /// Crafts a hotel-specific prompt with budget and preference details.
    private func craftHotelPrompt(destination: String, dates: String, budget: String?) -> String {
        var prompt = "Find hotels in \(destination) for \(dates). "
        if let budget = budget {
            prompt += "Budget: under \(budget)/night. "
        }
        prompt += "Include ratings, location highlights, and cancellation policy."
        return prompt
    }
}

// MARK: - OnDeviceAgent (LLM-Orchestrated)

/// An on-device orchestrator that uses an IntentRouter (backed by an LLM) to
/// classify user intent, select remote agents, and craft per-agent prompts.
///
/// Unlike the basic TravelPlannerAgent which uses hardcoded tag matching,
/// this orchestrator delegates routing decisions to the IntentRouter, enabling
/// natural language queries like "I want to spend a week in Tokyo in April,
/// what's the weather like and find me flights and a nice hotel under $250/night".
struct OnDeviceAgent: Sendable {
    /// Domains where we expect to find A2A agents via well-known discovery.
    let agentDomains: [String]

    /// The intent router that classifies queries and selects agents.
    let router: any IntentRouter

    init(
        agentDomains: [String] = ["flights.example.com", "hotels.example.com", "weather.example.com"],
        router: any IntentRouter = SimulatedIntentRouter()
    ) {
        self.agentDomains = agentDomains
        self.router = router
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

                if card.capabilities.streaming == true {
                    print("  - Supports streaming")
                }
                for skill in card.skills {
                    print("  - Skill: \(skill.name) [tags: \(skill.tags.joined(separator: ", "))]")
                }
            } catch {
                print("Could not discover agent at \(domain): \(error.localizedDescription)")
            }
        }

        return agents
    }

    // MARK: - Weather Check (Blocking Request)

    /// Checks weather using a blocking sendMessage call.
    func checkWeather(prompt: String, using agent: RemoteAgent) async throws -> String {
        let config = MessageSendConfiguration(blocking: true)
        let response = try await agent.client.sendMessage(prompt, configuration: config)

        switch response {
        case .message(let message):
            return message.textContent

        case .task(let task):
            if task.isComplete, let message = task.status.message {
                return message.textContent
            }
            return task.artifacts?.first?.textContent ?? "Weather data received (task \(task.id))"
        }
    }

    // MARK: - Flight Search via Streaming

    /// Searches for flights using streaming.
    func searchFlights(prompt: String, using agent: RemoteAgent) async throws -> String {
        let stream = try await agent.client.sendStreamingMessage(prompt)

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
                let chunk = update.artifact.textContent
                flightResults += chunk
                print("Flight result chunk: \(chunk.prefix(80))...")

            case .task(let task):
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
    func searchFlightsBlocking(prompt: String, using agent: RemoteAgent) async throws -> String {
        let response = try await agent.client.sendMessage(prompt)

        guard let task = response.task else {
            if let message = response.message {
                return message.textContent
            }
            throw OrchestratorError.unexpectedResponse(detail: "Expected a task or message")
        }

        var current = task
        while !current.isComplete && !current.needsInput {
            try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
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
    func bookHotel(prompt: String, using agent: RemoteAgent) async throws -> String {
        let contextId = UUID().uuidString

        var response = try await agent.client.sendMessage(prompt, contextId: contextId)

        var turnCount = 0
        let maxTurns = 5

        while let task = response.task, task.needsInput, turnCount < maxTurns {
            turnCount += 1

            let agentQuestion = task.status.message?.textContent ?? "Please provide more details"
            print("Hotel agent asks (turn \(turnCount)): \(agentQuestion)")

            let followUp: String
            switch turnCount {
            case 1: followUp = "Budget is $200-300 per night, prefer 4-star hotels"
            case 2: followUp = "Yes, confirm that booking please"
            default: followUp = "Yes"
            }

            response = try await agent.client.sendMessage(
                followUp,
                contextId: contextId,
                taskId: task.id
            )
        }

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

    // MARK: - Plan Trip (LLM-Routed Concurrent Orchestration)

    /// Orchestrates agents using the IntentRouter to classify intent and select agents.
    ///
    /// Instead of hardcoded tag lookups, the router analyzes the user's natural
    /// language query and returns agent assignments with crafted prompts.
    func planTrip(query: String) async throws -> TravelPlan {
        let agents = await discoverAgents()

        // Let the router classify intent and select agents
        let assignments = try await router.route(intent: query, agents: agents)

        if assignments.isEmpty {
            throw OrchestratorError.routingFailed(
                detail: "No agents matched the query: \"\(query)\""
            )
        }

        print("\nRouter assigned \(assignments.count) agent(s):")
        for assignment in assignments {
            print("  - \(assignment.category.rawValue): \(assignment.agent.card.name)")
            print("    Prompt: \(assignment.prompt.prefix(80))...")
        }
        print()

        // Dispatch to all assigned agents concurrently
        let results = try await withThrowingTaskGroup(
            of: (String, String).self,
            returning: [String: String].self
        ) { group in
            for assignment in assignments {
                group.addTask {
                    let result: String
                    switch assignment.category {
                    case .weather:
                        result = try await self.checkWeather(
                            prompt: assignment.prompt, using: assignment.agent
                        )
                    case .flights:
                        if assignment.agent.supportsStreaming {
                            result = try await self.searchFlights(
                                prompt: assignment.prompt, using: assignment.agent
                            )
                        } else {
                            result = try await self.searchFlightsBlocking(
                                prompt: assignment.prompt, using: assignment.agent
                            )
                        }
                    case .hotel:
                        result = try await self.bookHotel(
                            prompt: assignment.prompt, using: assignment.agent
                        )
                    }
                    return (assignment.category.rawValue, result)
                }
            }

            var collected: [String: String] = [:]
            for try await (key, value) in group {
                collected[key] = value
            }
            return collected
        }

        var plan = TravelPlan()
        if let weather = results["weather"] { plan.weather = weather }
        if let flights = results["flights"] { plan.flights = flights }
        if let hotel = results["hotel"] { plan.hotel = hotel }

        return plan
    }
}

// MARK: - Entry Point

@main
struct SmartTravelPlannerApp {
    static func main() async {
        print("=== A2A Smart Travel Planner (LLM-Routed) ===\n")

        // In production, the router would be backed by a real LLM.
        // Here we use the simulated router to demonstrate the pattern.
        let router = SimulatedIntentRouter()

        let orchestrator = OnDeviceAgent(
            agentDomains: [
                "flights.example.com",
                "hotels.example.com",
                "weather.example.com",
            ],
            router: router
        )

        // A natural language query — the router parses this into structured
        // intents and crafts per-agent prompts automatically.
        let query = """
            I want to spend a week in Tokyo in April, what's the weather like \
            and find me flights and a nice hotel under $250/night
            """

        print("User query: \"\(query)\"\n")

        do {
            let plan = try await orchestrator.planTrip(query: query)

            print("\n=== Travel Plan ===")
            print("Weather:  \(plan.weather)")
            print("Flights:  \(plan.flights)")
            print("Hotel:    \(plan.hotel)")
            print("===================")
        } catch let error as OrchestratorError {
            print("Orchestrator error: \(error.localizedDescription)")
        } catch let error as A2AError {
            print("A2A error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error: \(error.localizedDescription)")
        }
    }
}
