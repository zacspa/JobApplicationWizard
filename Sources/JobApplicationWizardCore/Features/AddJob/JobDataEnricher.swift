import Foundation

// MARK: - Job Parse Prompt (shared by ACP and Claude API paths)

let jobParseSystemPrompt = """
You are a job posting data extractor. Given raw text from a job listing, extract structured fields. \
Respond ONLY with a JSON object containing these keys: title, company, location, salary, description, requirements. \
Use empty strings for fields you cannot determine. Do not include any other text.
"""

/// Builds the full prompt for parsing a job listing. For ACP, this is sent as a single message
/// (system instructions + user content). For Claude API, only the user portion is used.
func jobParsePrompt(for text: String) -> String {
    let truncated = String(text.prefix(12_000))
    return """
    \(jobParseSystemPrompt)

    Extract structured job data from this text:

    \(truncated)
    """
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

// MARK: - Enrichment (HTML fallback, Claude API only)

/// Takes scraped job data and uses Claude to fill in missing fields.
/// Skips enrichment entirely when the scraped data is already complete.
public func enrichJobData(
    scraped: ScrapedJobData,
    chat: @Sendable (String, String, [ChatMessage], Bool) async throws -> (String, AITokenUsage, AgentActionBlock?),
    apiKey: String
) async throws -> ScrapedJobData {
    // Skip enrichment when ATS API returned complete data
    guard !scraped.isComplete else { return scraped }
    guard !apiKey.isEmpty else { return scraped }

    let truncatedHTML = String(scraped.rawHTML.prefix(8_000))

    let systemPrompt = """
    You are a job posting data extractor. Given partial job data and raw HTML, extract structured fields. \
    Respond ONLY with a JSON object containing these keys: title, company, location, salary, description, requirements. \
    Use empty strings for fields you cannot determine. Do not include any other text.
    """

    var contextParts: [String] = []
    if !scraped.title.isEmpty { contextParts.append("Title: \(scraped.title)") }
    if !scraped.company.isEmpty { contextParts.append("Company: \(scraped.company)") }
    if !scraped.location.isEmpty { contextParts.append("Location: \(scraped.location)") }
    if !scraped.salary.isEmpty { contextParts.append("Salary: \(scraped.salary)") }
    if !scraped.description.isEmpty { contextParts.append("Description: \(scraped.description.prefix(2_000))") }

    let userMessage = """
    Known fields:
    \(contextParts.isEmpty ? "(none)" : contextParts.joined(separator: "\n"))

    Raw HTML (truncated):
    \(truncatedHTML)
    """

    let messages = [ChatMessage(role: .user, content: userMessage)]
    let (responseText, _, _) = try await chat(apiKey, systemPrompt, messages, false)

    // Parse the JSON response
    guard let data = responseText.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return scraped
    }

    // Merge: scraped data wins when both present
    var enriched = scraped
    if enriched.title.isEmpty, let v = json["title"] as? String, !v.isEmpty {
        enriched.title = v
    }
    if enriched.company.isEmpty, let v = json["company"] as? String, !v.isEmpty {
        enriched.company = v
    }
    if enriched.location.isEmpty, let v = json["location"] as? String, !v.isEmpty {
        enriched.location = v
    }
    if enriched.salary.isEmpty, let v = json["salary"] as? String, !v.isEmpty {
        enriched.salary = v
    }
    if enriched.description.isEmpty, let v = json["description"] as? String, !v.isEmpty {
        enriched.description = v
    }
    if enriched.requirements.isEmpty, let v = json["requirements"] as? String, !v.isEmpty {
        enriched.requirements = v
    }

    return enriched
}
