//
//  ClaudeClient.swift
//  Calor
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Claude models offered in Settings. Prices are US dollars per million tokens.
enum ClaudeModel: String, CaseIterable, Identifiable {
    case haiku = "claude-haiku-4-5"
    case sonnet = "claude-sonnet-5-5"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .haiku: "Haiku 4.5"
        case .sonnet: "Sonnet 5.5"
        }
    }

    var detail: String {
        switch self {
        case .haiku: "Fast and cheapest, about US$0.003 a photo."
        case .sonnet: "Better with mixed plates, about US$0.006 a photo."
        }
    }

    var inputPrice: Double { self == .haiku ? 1 : 2 }
    var outputPrice: Double { self == .haiku ? 5 : 10 }

    func cost(inputTokens: Int, outputTokens: Int) -> Double {
        (Double(inputTokens) * inputPrice + Double(outputTokens) * outputPrice) / 1_000_000
    }

    /// The model chosen in Settings.
    static var current: ClaudeModel {
        UserDefaults.standard.string(forKey: SettingsKey.aiModel).flatMap(ClaudeModel.init(rawValue:)) ?? .haiku
    }

    /// Display name for the model that answered. A fallback may be a different model.
    static func displayName(for id: String?) -> String? {
        guard let id else { return nil }
        if let model = allCases.first(where: { id.hasPrefix($0.rawValue) }) { return model.title }
        if id.hasPrefix("claude-sonnet-5") { return "Sonnet 5" }
        return id
    }
}

/// What to analyse.
enum MealInput {
    /// A photo, already made small (`ImageProcessing.analysisJPEG`), with an optional
    /// note such as "half rice".
    case photo(jpeg: Data, hint: String?)
    /// A meal described in words, e.g. "2 roti canai with dhal and a teh tarik".
    case text(String)
}

/// Builds requests for the Claude Messages API. Plain HTTP: there's no official Swift SDK.
enum ClaudeRequest {
    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    /// Listing models is free, so it's used to check an API key.
    static let modelsURL = URL(string: "https://api.anthropic.com/v1/models?limit=1")!
    static let apiVersion = "2023-06-01"
    /// Lets Sonnet 5.5 hand a declined request to another model in the same call.
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    /// A plate of several items needs about 400 tokens; this leaves room.
    static let maxTokens = 1024
    static let hintLimit = 200
    static let descriptionLimit = 500

    static let systemPrompt = """
    You estimate calories and macros for a personal calorie tracker used in Malaysia.
    - List each distinct food or drink. Use common Malaysian names where they fit (nasi lemak, roti canai, teh tarik, kuih).
    - Estimate the portion actually shown or described (e.g. "1 plate", "1 cup", "2 pieces") and the calories, protein, carbs and fat for that portion. Hawker portions are often larger and oilier than Western references: count cooking oil, santan, condensed milk and sugar.
    - Follow any note from the user, such as "half rice" or "no sugar".
    - health_score for each item: 1 to 10. 10 is nutritious and minimally processed (vegetables, fruit, lean protein, whole grains); 1 is mostly sugar, deep-fried or refined with little nutrition.
    - confidence: "high" when the items and portions are clear, "low" when hidden ingredients or portion size are hard to judge.
    - If there is no food or drink, set is_food to false and return no items.
    - notes: one short sentence about what was hardest to judge, or an empty string.
    """

    /// The answer's shape. Structured outputs make Claude follow it exactly.
    static var schema: [String: Any] {
        let item: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "portion": ["type": "string"],
                "calories": ["type": "integer"],
                "protein_g": ["type": "number"],
                "carbs_g": ["type": "number"],
                "fat_g": ["type": "number"],
                "health_score": ["type": "integer", "description": "1 to 10"],
            ],
            "required": ["name", "portion", "calories", "protein_g", "carbs_g", "fat_g", "health_score"],
            "additionalProperties": false,
        ]
        return [
            "type": "object",
            "properties": [
                "is_food": ["type": "boolean"],
                "items": ["type": "array", "items": item],
                "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
                "notes": ["type": "string"],
            ],
            "required": ["is_food", "items", "confidence", "notes"],
            "additionalProperties": false,
        ]
    }

    static func body(for input: MealInput, model: ClaudeModel, fallbacks: Bool) -> [String: Any] {
        var content: [[String: Any]] = []
        switch input {
        case .photo(let jpeg, let hint):
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()],
            ])
            var text = "Estimate this meal."
            if let hint = cleaned(hint, limit: hintLimit) {
                text += "\nNote from me: \(hint)"
            }
            content.append(["type": "text", "text": text])
        case .text(let description):
            let text = cleaned(description, limit: descriptionLimit) ?? ""
            content.append(["type": "text", "text": "Estimate this meal from my description: \(text)"])
        }

        var outputConfig: [String: Any] = ["format": ["type": "json_schema", "schema": schema]]
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [["role": "user", "content": content]],
        ]
        if model == .sonnet {
            // One quick estimate doesn't need extended thinking, which would add cost.
            body["thinking"] = ["type": "between_tools"]
            outputConfig["effort"] = "low"
            if fallbacks {
                body["fallbacks"] = "default"
            }
        }
        body["output_config"] = outputConfig
        return body
    }

    static func messagesRequest(for input: MealInput, model: ClaudeModel, apiKey: String,
                                fallbacks: Bool) throws -> URLRequest {
        let useFallbacks = fallbacks && model == .sonnet
        var request = URLRequest(url: messagesURL, timeoutInterval: 60)
        request.httpMethod = "POST"
        addHeaders(to: &request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if useFallbacks {
            request.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body(for: input, model: model, fallbacks: useFallbacks))
        return request
    }

    static func keyCheckRequest(apiKey: String) -> URLRequest {
        var request = URLRequest(url: modelsURL, timeoutInterval: 20)
        addHeaders(to: &request, apiKey: apiKey)
        return request
    }

    private static func addHeaders(to request: inout URLRequest, apiKey: String) {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
    }

    /// Trimmed and shortened, or nil if blank.
    static func cleaned(_ text: String?, limit: Int) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(limit))
    }
}

/// The parts of a Messages API response that Calor uses.
struct ClaudeResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        /// One entry per model that ran, when a fallback was used.
        let iterations: [Iteration]?

        struct Iteration: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
        }

        /// Tokens to pay for, counting every model that ran.
        var billed: (input: Int, output: Int) {
            var input = (inputTokens ?? 0) + (cacheCreationInputTokens ?? 0) + (cacheReadInputTokens ?? 0)
            var output = outputTokens ?? 0
            if let iterations, !iterations.isEmpty {
                input = max(input, iterations.reduce(0) { $0 + ($1.inputTokens ?? 0) })
                output = max(output, iterations.reduce(0) { $0 + ($1.outputTokens ?? 0) })
            }
            return (input, output)
        }
    }

    let model: String?
    let content: [Block]
    let stopReason: String?
    let usage: Usage?

    static func decode(_ data: Data) throws -> ClaudeResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ClaudeResponse.self, from: data)
    }

    /// The JSON answer: the first text block. Blocks are read by type, not position.
    var text: String? {
        content.first { $0.type == "text" }?.text
    }
}

enum ClaudeError: LocalizedError, Equatable {
    case invalidKey
    case billing
    case permission
    case modelUnavailable
    case rateLimited
    case busy
    case tooLarge
    case badRequest(String?)
    case refused
    case cutOff
    case unreadable
    case offline
    case network
    /// Stopped by the in-app budget (`AIBudget`) before anything was sent.
    case budget(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            "Your Claude API key isn't working. Check it in Settings → Photo analysis."
        case .billing:
            "Your Claude account is out of credit or has reached its monthly spend limit. Check Billing and Limits in the Claude Console."
        case .permission:
            "This API key isn't allowed to do this. Check the key's workspace in the Claude Console."
        case .modelUnavailable:
            "The chosen Claude model isn't available to your key. Pick another model in Settings."
        case .rateLimited:
            "Too many requests at once. Wait a minute and try again."
        case .busy:
            "Claude is busy right now. Try again in a minute."
        case .tooLarge:
            "This photo is too large to send. Try another one."
        case .badRequest(let message):
            "Claude couldn't read the request." + (message.map { " (\($0))" } ?? "")
        case .refused:
            "Claude couldn't analyse this. Try another photo, or add the meal manually."
        case .cutOff:
            "The answer was cut off. Try again."
        case .unreadable:
            "Claude's answer couldn't be read. Try again."
        case .offline:
            "No internet connection. Try again when you're online."
        case .network:
            "The connection dropped. Try again."
        case .budget(let message):
            message
        }
    }

    /// Trying again might work. Key, billing and budget problems need fixing first.
    var canRetry: Bool {
        switch self {
        case .rateLimited, .busy, .cutOff, .unreadable, .offline, .network: true
        default: false
        }
    }

    /// Maps an unsuccessful HTTP response.
    static func from(status: Int, body: Data) -> ClaudeError {
        struct ErrorBody: Decodable {
            struct Detail: Decodable {
                let type: String?
                let message: String?
            }
            let error: Detail?
        }
        let detail = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.error
        let message = detail?.message
        let lower = message?.lowercased() ?? ""
        let soundsLikeBilling = ["credit balance", "spend limit", "usage limit", "billing"].contains { lower.contains($0) }

        if detail?.type == "billing_error" || status == 402 || soundsLikeBilling { return .billing }
        switch status {
        case 401: return .invalidKey
        case 403: return .permission
        case 404: return .modelUnavailable
        case 413: return .tooLarge
        case 429: return .rateLimited
        case 500...599: return .busy
        default: return .badRequest(message)
        }
    }

    /// True for a 400 that turns down the fallback option (beta not enabled), so the
    /// request can be sent again without it.
    static func rejectsFallback(status: Int, body: Data) -> Bool {
        guard status == 400 else { return false }
        let text = String(decoding: body, as: UTF8.self).lowercased()
        return text.contains("anthropic-beta") || text.contains("fallback")
    }

    /// Maps a network failure, and says whether the request may have reached Claude
    /// (and so may be billed) before the connection failed.
    static func from(_ error: URLError) -> (error: ClaudeError, mayHaveBeenSent: Bool) {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            (.offline, false)
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            (.network, false)
        default:
            (.network, true)
        }
    }
}

/// Sends meals to Claude for analysis, within the budget (`AIBudget`).
struct ClaudeFoodAnalyzer: FoodAnalyzer {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    let apiKey: String
    let model: ClaudeModel
    var budget = AIBudget()
    var transport: Transport = { try await URLSession.shared.data(for: $0) }
    /// Wait before the one automatic retry when Claude is busy.
    var busyRetryDelay = Duration.seconds(2)

    var isDemo: Bool { false }

    func analyze(_ input: MealInput) async throws -> AnalysisResult {
        var useFallbacks = model == .sonnet && !budget.fallbacksUnsupported
        let worstCase = AIBudget.worstCaseCost(for: input, model: model, fallbacks: useFallbacks)
        try budget.checkAllowed(worstCase: worstCase)

        var hasRetriedBusy = false
        while true {
            try Task.checkCancellation()
            let request = try ClaudeRequest.messagesRequest(for: input, model: model, apiKey: apiKey,
                                                            fallbacks: useFallbacks)
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await transport(request)
            } catch let error as URLError {
                let mapped = ClaudeError.from(error)
                if mapped.mayHaveBeenSent {
                    // Claude may have answered before the connection dropped. Count the
                    // most it could have cost, so the limit is never passed.
                    budget.record(cost: worstCase)
                }
                throw error.code == .cancelled ? CancellationError() : mapped.error
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                return try result(from: data, worstCase: worstCase)
            }
            // Failed requests aren't billed, so these retries cost nothing.
            if useFallbacks && ClaudeError.rejectsFallback(status: status, body: data) {
                budget.markFallbacksUnsupported()
                useFallbacks = false
                continue
            }
            let error = ClaudeError.from(status: status, body: data)
            if error == .busy && !hasRetriedBusy {
                hasRetriedBusy = true
                try await Task.sleep(for: busyRetryDelay)
                continue
            }
            throw error
        }
    }

    private func result(from data: Data, worstCase: Double) throws -> AnalysisResult {
        guard let response = try? ClaudeResponse.decode(data) else {
            budget.record(cost: worstCase)
            throw ClaudeError.unreadable
        }
        let tokens = response.usage?.billed ?? (input: 0, output: 0)
        let cost = response.usage == nil ? worstCase : model.cost(inputTokens: tokens.input, outputTokens: tokens.output)
        budget.record(cost: cost)

        // Check why it stopped before reading the answer: a refusal or a cut-off
        // answer may not match the schema.
        switch response.stopReason {
        case "refusal": throw ClaudeError.refused
        case "max_tokens": throw ClaudeError.cutOff
        default: break
        }
        guard let text = response.text,
              let analysis = try? JSONDecoder().decode(FoodAnalysis.self, from: Data(text.utf8)) else {
            throw ClaudeError.unreadable
        }
        return AnalysisResult(analysis: analysis, costUSD: cost,
                              modelName: ClaudeModel.displayName(for: response.model) ?? model.title)
    }
}

/// Checks an API key with a free request, before it's saved.
enum ClaudeKeyCheck {
    enum Outcome: Equatable {
        case valid
        case invalid
        case failed(String)
    }

    static func check(_ apiKey: String,
                      transport: ClaudeFoodAnalyzer.Transport = { try await URLSession.shared.data(for: $0) }) async -> Outcome {
        do {
            let (data, response) = try await transport(ClaudeRequest.keyCheckRequest(apiKey: apiKey))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200: return .valid
            case 401: return .invalid
            default: return .failed(ClaudeError.from(status: status, body: data).localizedDescription)
            }
        } catch let error as URLError {
            return .failed(ClaudeError.from(error).error.localizedDescription)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
