import Foundation

// MARK: - Job Parse Prompt (shared by ACP and Claude API paths)

let jobParseSystemPrompt = """
You are a job posting data extractor. Given raw text from a job listing, extract structured fields. \
Respond ONLY with a JSON object containing these keys: title, company, location, salary, description, requirements. \
Use empty strings for fields you cannot determine. Do not include any other text.
"""

/// Builds the user portion of the prompt for parsing a job listing.
func jobParseUserPrompt(for text: String) -> String {
    let truncated = String(text.prefix(12_000))
    return "Extract structured job data from this text:\n\n\(truncated)"
}

/// Builds the full prompt for ACP (system instructions + user content in a single message).
func jobParsePromptACP(for text: String) -> String {
    return "\(jobParseSystemPrompt)\n\n\(jobParseUserPrompt(for: text))"
}

/// Parses the JSON response from either ACP or Claude API into ScrapedJobData.
/// Handles code fences, leading prose, and other common AI response quirks.
func parseJobJSON(_ responseText: String) throws -> ScrapedJobData {
    // Strip markdown code fences if the model wrapped its response
    var cleaned = responseText
        .replacingOccurrences(of: #"^```(?:json)?\s*\n?"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\n?```\s*$"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Try parsing as-is first
    if let json = tryParseJSON(cleaned) {
        return scrapedData(from: json)
    }

    // The model may have wrapped JSON in prose; find the first { ... } block
    if let openBrace = cleaned.firstIndex(of: "{"),
       let closeBrace = cleaned.lastIndex(of: "}") {
        cleaned = String(cleaned[openBrace...closeBrace])
        if let json = tryParseJSON(cleaned) {
            return scrapedData(from: json)
        }
    }

    throw JobURLError.parsingError("AI response was not valid JSON")
}

private func tryParseJSON(_ text: String) -> [String: Any]? {
    guard let data = text.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func scrapedData(from json: [String: Any]) -> ScrapedJobData {
    ScrapedJobData(
        title: json["title"] as? String ?? "",
        company: json["company"] as? String ?? "",
        location: json["location"] as? String ?? "",
        salary: json["salary"] as? String ?? "",
        description: json["description"] as? String ?? "",
        requirements: json["requirements"] as? String ?? ""
    )
}

// MARK: - Enrichment (ACP or Claude API)

private let enrichSystemPrompt = """
You are a job posting data extractor. Given partial job data and raw page content, extract structured fields. \
Respond ONLY with a JSON object containing these keys: title, company, location, salary, description, requirements. \
Use empty strings for fields you cannot determine. Do not include any other text.
"""

private func enrichUserMessage(scraped: ScrapedJobData) -> String {
    let truncatedHTML = String(scraped.rawHTML.prefix(8_000))
    var contextParts: [String] = []
    if !scraped.title.isEmpty { contextParts.append("Title: \(scraped.title)") }
    if !scraped.company.isEmpty { contextParts.append("Company: \(scraped.company)") }
    if !scraped.location.isEmpty { contextParts.append("Location: \(scraped.location)") }
    if !scraped.salary.isEmpty { contextParts.append("Salary: \(scraped.salary)") }
    if !scraped.description.isEmpty { contextParts.append("Description: \(scraped.description.prefix(2_000))") }

    return """
    Known fields:
    \(contextParts.isEmpty ? "(none)" : contextParts.joined(separator: "\n"))

    Raw page content (truncated):
    \(truncatedHTML)
    """
}

/// Takes scraped job data and uses AI to fill in missing fields.
/// Supports both ACP and Claude API paths.
public func enrichJobData(
    scraped: ScrapedJobData,
    useACP: Bool,
    acpSend: @Sendable (String, [ChatMessage]) async throws -> (String, AITokenUsage),
    chat: @Sendable (String, String, [ChatMessage], Bool) async throws -> (String, AITokenUsage, AgentActionBlock?),
    apiKey: String
) async throws -> ScrapedJobData {
    guard !scraped.isComplete else { return scraped }

    let userMessage = enrichUserMessage(scraped: scraped)
    let responseText: String

    if useACP {
        let fullPrompt = "\(enrichSystemPrompt)\n\n\(userMessage)"
        let (text, _) = try await acpSend(fullPrompt, [])
        responseText = text
    } else {
        guard !apiKey.isEmpty else { return scraped }
        let messages = [ChatMessage(role: .user, content: userMessage)]
        let (text, _, _) = try await chat(apiKey, enrichSystemPrompt, messages, false)
        responseText = text
    }

    // Parse the JSON response, handling code fences
    let parsed = try? parseJobJSON(responseText)
    guard let parsed else { return scraped }

    // Merge: scraped data wins when both present
    var enriched = scraped
    if enriched.title.isEmpty { enriched.title = parsed.title }
    if enriched.company.isEmpty { enriched.company = parsed.company }
    if enriched.location.isEmpty { enriched.location = parsed.location }
    if enriched.salary.isEmpty { enriched.salary = parsed.salary }
    if enriched.description.isEmpty { enriched.description = parsed.description }
    if enriched.requirements.isEmpty { enriched.requirements = parsed.requirements }

    return enriched
}
