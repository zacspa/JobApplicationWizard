import Foundation
import ComposableArchitecture

// MARK: - Token Usage

public struct AITokenUsage: Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public static let zero = AITokenUsage(inputTokens: 0, outputTokens: 0)

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    /// Estimated cost in USD using claude-sonnet-4-6 pricing ($3/MTok in, $15/MTok out)
    public var estimatedCost: Double {
        Double(inputTokens) * 3.0 / 1_000_000 + Double(outputTokens) * 15.0 / 1_000_000
    }

    public var totalTokens: Int { inputTokens + outputTokens }
}

// MARK: - ClaudeClient

public struct ClaudeClient {
    /// Chat with optional tool_use support.
    /// Returns (responseText, usage, agentActionBlock?) where agentActionBlock is non-nil
    /// if the model used the apply_actions tool.
    public var chat: @Sendable (String, String, [ChatMessage], Bool) async throws -> (String, AITokenUsage, AgentActionBlock?)
    // (apiKey, systemPrompt, messageHistory, includeTools) -> (responseText, usage, actions?)

    public init(
        chat: @escaping @Sendable (String, String, [ChatMessage], Bool) async throws -> (String, AITokenUsage, AgentActionBlock?)
    ) {
        self.chat = chat
    }
}

extension ClaudeClient: DependencyKey {
    public static var liveValue: ClaudeClient {
        ClaudeClient(
            chat: { apiKey, systemPrompt, history, includeTools in
                let messages = history.map { msg -> [String: String] in
                    ["role": msg.role == .user ? "user" : "assistant",
                     "content": msg.content]
                }
                return try await sendChatRequest(
                    apiKey: apiKey,
                    system: systemPrompt,
                    messages: messages,
                    includeTools: includeTools
                )
            }
        )
    }
}

private func sendChatRequest(
    apiKey: String,
    system: String,
    messages: [[String: String]],
    includeTools: Bool
) async throws -> (String, AITokenUsage, AgentActionBlock?) {
    guard !apiKey.isEmpty else { throw AIError.noAPIKey }

    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    var body: [String: Any] = [
        "model": "claude-sonnet-4-6",
        "max_tokens": 2048,
        "system": system,
        "messages": messages
    ]

    if includeTools {
        body["tools"] = [applyActionsToolDefinition]
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
    guard http.statusCode == 200 else {
        let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AIError.apiError(http.statusCode, msg)
    }

    let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)

    // Extract text from text blocks
    let textParts = decoded.content.compactMap { block -> String? in
        if case .text(let text) = block { return text }
        return nil
    }
    let text = textParts.joined(separator: "\n")

    // Extract tool_use blocks for apply_actions
    var actionBlock: AgentActionBlock? = nil
    for block in decoded.content {
        if case .toolUse(_, let name, let input) = block, name == "apply_actions" {
            if let inputData = try? JSONSerialization.data(withJSONObject: input) {
                actionBlock = try? JSONDecoder().decode(AgentActionBlock.self, from: inputData)
            }
        }
    }

    let usage = AITokenUsage(
        inputTokens: decoded.usage.inputTokens,
        outputTokens: decoded.usage.outputTokens
    )
    return (text, usage, actionBlock)
}

// MARK: - Response Types

private struct ClaudeResponse: Decodable {
    enum ContentBlock: Decodable {
        case text(String)
        case toolUse(id: String, name: String, input: [String: Any])

        private enum CodingKeys: String, CodingKey {
            case type, text, id, name, input
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "text":
                let text = try c.decode(String.self, forKey: .text)
                self = .text(text)
            case "tool_use":
                let id = try c.decode(String.self, forKey: .id)
                let name = try c.decode(String.self, forKey: .name)
                // Decode input as raw JSON dictionary
                let inputContainer = try c.decode(AnyCodable.self, forKey: .input)
                let input = inputContainer.value as? [String: Any] ?? [:]
                self = .toolUse(id: id, name: name, input: input)
            default:
                // Skip unknown content block types
                self = .text("")
            }
        }
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    let content: [ContentBlock]
    let usage: Usage
}

/// Helper for decoding arbitrary JSON values.
private struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.typeMismatch(Any.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Errors

public enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(Int, String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Claude API key. Add it in Settings."
        case .invalidResponse: return "Invalid response from Claude API."
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        }
    }
}

extension ClaudeClient: TestDependencyKey {
    public static let testValue = ClaudeClient(
        chat: unimplemented("\(Self.self).chat", placeholder: ("", .zero, nil))
    )
}

extension DependencyValues {
    public var claudeClient: ClaudeClient {
        get { self[ClaudeClient.self] }
        set { self[ClaudeClient.self] = newValue }
    }
}
