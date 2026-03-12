import Foundation
import ComposableArchitecture

// MARK: - ClaudeClient

struct ClaudeClient {
    var chat: @Sendable (String, String, [ChatMessage]) async throws -> String
    // (apiKey, systemPrompt, messageHistory)
}

extension ClaudeClient: DependencyKey {
    static var liveValue: ClaudeClient {
        ClaudeClient(
            chat: { apiKey, systemPrompt, history in
                let messages = history.map { msg -> [String: String] in
                    ["role": msg.role == .user ? "user" : "assistant",
                     "content": msg.content]
                }
                return try await sendChatRequest(apiKey: apiKey, system: systemPrompt, messages: messages)
            }
        )
    }
}

private func sendChatRequest(apiKey: String, system: String, messages: [[String: String]]) async throws -> String {
    guard !apiKey.isEmpty else { throw AIError.noAPIKey }

    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

    let body: [String: Any] = [
        "model": "claude-sonnet-4-6",
        "max_tokens": 2048,
        "system": system,
        "messages": messages
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
    guard http.statusCode == 200 else {
        let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AIError.apiError(http.statusCode, msg)
    }

    let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
    return decoded.content.first?.text ?? ""
}

private struct ClaudeResponse: Decodable {
    struct Content: Decodable { let text: String }
    let content: [Content]
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Claude API key. Add it in Settings."
        case .invalidResponse: return "Invalid response from Claude API."
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        }
    }
}

extension DependencyValues {
    var claudeClient: ClaudeClient {
        get { self[ClaudeClient.self] }
        set { self[ClaudeClient.self] = newValue }
    }
}
