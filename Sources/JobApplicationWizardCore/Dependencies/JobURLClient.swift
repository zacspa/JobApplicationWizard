import Foundation
import ComposableArchitecture

// MARK: - ATS Provider

public enum ATSProvider: String, Codable, Equatable, Sendable {
    case greenhouse
    case lever
    case unknown
}

// MARK: - Scraped Job Data

public struct ScrapedJobData: Equatable, Sendable {
    public var title: String
    public var company: String
    public var location: String
    public var salary: String
    public var description: String
    public var requirements: String
    public var atsProvider: ATSProvider
    public var rawHTML: String

    public init(
        title: String = "",
        company: String = "",
        location: String = "",
        salary: String = "",
        description: String = "",
        requirements: String = "",
        atsProvider: ATSProvider = .unknown,
        rawHTML: String = ""
    ) {
        self.title = title
        self.company = company
        self.location = location
        self.salary = salary
        self.description = description
        self.requirements = requirements
        self.atsProvider = atsProvider
        self.rawHTML = rawHTML
    }

    /// True when the structured fields are all populated (ATS API returned everything).
    public var isComplete: Bool {
        !title.isEmpty && !company.isEmpty && !location.isEmpty && !description.isEmpty
    }
}

// MARK: - Job URL Error

public enum JobURLError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case parsingError(String)
    case loginRequired(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is not valid."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Could not parse job data: \(message)"
        case .loginRequired(let domain):
            return "\(domain) requires login to view full job details. Paste the job description into the form instead."
        }
    }
}

// MARK: - JobURLClient

public struct JobURLClient {
    public var detectATS: @Sendable (URL) -> ATSProvider
    public var fetchJobData: @Sendable (URL) async throws -> ScrapedJobData

    public init(
        detectATS: @escaping @Sendable (URL) -> ATSProvider,
        fetchJobData: @escaping @Sendable (URL) async throws -> ScrapedJobData
    ) {
        self.detectATS = detectATS
        self.fetchJobData = fetchJobData
    }
}

// MARK: - ATS Detection (pure URL pattern matching)

private func detectATSProvider(_ url: URL) -> ATSProvider {
    let host = url.host?.lowercased() ?? ""
    let path = url.path.lowercased()

    // Greenhouse: boards.greenhouse.io/company/jobs/123 or job-boards.greenhouse.io
    if host.contains("greenhouse.io") {
        return .greenhouse
    }
    // Lever: jobs.lever.co/company/uuid
    if host.contains("lever.co") {
        return .lever
    }
    // Some companies embed ATS in their own domain but path/query hints at provider
    let fullString = url.absoluteString.lowercased()
    if path.contains("/greenhouse/") || fullString.contains("gh_jid=") {
        return .greenhouse
    }
    if path.contains("/lever/") {
        return .lever
    }

    return .unknown
}

// MARK: - Greenhouse API

/// Extracts board token and job ID from a Greenhouse URL.
/// Patterns: boards.greenhouse.io/{token}/jobs/{id}, boards.greenhouse.io/embed/job_app?token={token}&id={id}
private func parseGreenhouseURL(_ url: URL) -> (boardToken: String, jobID: String)? {
    let path = url.path
    // /token/jobs/id
    let segments = path.split(separator: "/").map(String.init)
    if let jobsIndex = segments.firstIndex(of: "jobs"),
       jobsIndex > 0, jobsIndex + 1 < segments.count {
        return (segments[jobsIndex - 1], segments[jobsIndex + 1])
    }
    // query-param style
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
       let id = components?.queryItems?.first(where: { $0.name == "id" })?.value {
        return (token, id)
    }
    return nil
}

private func fetchGreenhouseJob(boardToken: String, jobID: String) async throws -> ScrapedJobData {
    guard let apiURL = URL(string: "https://boards-api.greenhouse.io/v1/boards/\(boardToken)/jobs/\(jobID)") else {
        throw JobURLError.parsingError("Could not build Greenhouse API URL")
    }
    let (data, response) = try await URLSession.shared.data(from: apiURL)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw JobURLError.networkError("Greenhouse API returned non-200 status")
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw JobURLError.parsingError("Invalid Greenhouse JSON")
    }

    let title = json["title"] as? String ?? ""
    let location = (json["location"] as? [String: Any])?["name"] as? String ?? ""
    let htmlContent = json["content"] as? String ?? ""
    // Strip HTML tags for plain-text description
    let description = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

    // Company name from metadata
    let company: String
    if let meta = json["metadata"] as? [[String: Any]],
       let companyMeta = meta.first(where: { ($0["name"] as? String) == "Company" }) {
        company = companyMeta["value"] as? String ?? ""
    } else {
        // Fall back to board token (often the company slug)
        company = boardToken.replacingOccurrences(of: "-", with: " ").capitalized
    }

    return ScrapedJobData(
        title: title,
        company: company,
        location: location,
        description: description,
        atsProvider: .greenhouse,
        rawHTML: htmlContent
    )
}

// MARK: - Lever API

/// Extracts company and posting ID from a Lever URL.
/// Pattern: jobs.lever.co/{company}/{uuid}
private func parseLeverURL(_ url: URL) -> (company: String, postingID: String)? {
    let segments = url.path.split(separator: "/").map(String.init)
    guard segments.count >= 2 else { return nil }
    return (segments[0], segments[1])
}

private func fetchLeverJob(company: String, postingID: String) async throws -> ScrapedJobData {
    guard let apiURL = URL(string: "https://api.lever.co/v0/postings/\(company)/\(postingID)") else {
        throw JobURLError.parsingError("Could not build Lever API URL")
    }
    let (data, response) = try await URLSession.shared.data(from: apiURL)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw JobURLError.networkError("Lever API returned non-200 status")
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw JobURLError.parsingError("Invalid Lever JSON")
    }

    let title = json["text"] as? String ?? ""
    let categories = json["categories"] as? [String: Any] ?? [:]
    let location = categories["location"] as? String ?? ""
    let commitment = categories["commitment"] as? String ?? ""

    // Build description from lists
    var descriptionParts: [String] = []
    if let description = json["descriptionPlain"] as? String {
        descriptionParts.append(description)
    }
    if let lists = json["lists"] as? [[String: Any]] {
        for list in lists {
            if let heading = list["text"] as? String {
                descriptionParts.append("\n\(heading)")
            }
            if let items = list["content"] as? String {
                let plain = items.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                descriptionParts.append(plain)
            }
        }
    }

    return ScrapedJobData(
        title: title,
        company: company.replacingOccurrences(of: "-", with: " ").capitalized,
        location: location,
        salary: commitment,
        description: descriptionParts.joined(separator: "\n"),
        atsProvider: .lever,
        rawHTML: String(data: data, encoding: .utf8) ?? ""
    )
}

// MARK: - Login Wall Detection

private let gatedDomains = ["linkedin.com", "indeed.com", "glassdoor.com", "ziprecruiter.com"]

/// Returns the gated domain name if the URL's host matches a known login-walled site, nil otherwise.
func matchGatedDomain(_ url: URL) -> String? {
    guard let host = url.host?.lowercased() else { return nil }
    return gatedDomains.first { host.contains($0) }
}

private let loginPathSegments = ["/login", "/signin", "/authwall", "/challenge", "/uas/login"]

/// Returns true if the response URL's path contains a known login/auth redirect segment.
func isLoginRedirect(_ responseURL: URL?) -> Bool {
    guard let path = responseURL?.path.lowercased() else { return false }
    return loginPathSegments.contains { path.contains($0) }
}

private let loginHTMLPatterns = [
    "see this and similar jobs on",
    "sign in to view",
    "log in to see",
    "id=\"auth-wall\"",
    "class=\"login-form\"",
    "class=\"authwall",
]

/// Returns true if the HTML body contains common auth-wall markers.
func containsLoginWallMarkers(_ html: String) -> Bool {
    let lower = html.lowercased()
    return loginHTMLPatterns.contains { lower.contains($0) }
}

// MARK: - HTML Fallback

private func fetchHTMLFallback(url: URL) async throws -> ScrapedJobData {
    let gatedDomain = matchGatedDomain(url)

    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
        throw JobURLError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
    }

    // Check for login redirect
    if isLoginRedirect(http.url) {
        let domain = gatedDomain ?? url.host ?? "This site"
        throw JobURLError.loginRequired(domain)
    }

    let html = String(data: data, encoding: .utf8) ?? ""

    // Check for login wall markers in HTML
    if containsLoginWallMarkers(html) {
        let domain = gatedDomain ?? url.host ?? "This site"
        throw JobURLError.loginRequired(domain)
    }

    var result = ScrapedJobData(atsProvider: .unknown, rawHTML: html)

    // Try JSON-LD JobPosting schema
    if let jsonLD = extractJSONLD(from: html) {
        result.title = jsonLD["title"] as? String ?? ""
        if let org = jsonLD["hiringOrganization"] as? [String: Any] {
            result.company = org["name"] as? String ?? ""
        }
        if let loc = jsonLD["jobLocation"] as? [String: Any],
           let address = loc["address"] as? [String: Any] {
            let parts = [
                address["addressLocality"] as? String,
                address["addressRegion"] as? String
            ].compactMap { $0 }
            result.location = parts.joined(separator: ", ")
        }
        if let salary = jsonLD["baseSalary"] as? [String: Any],
           let value = salary["value"] as? [String: Any] {
            let min = value["minValue"] as? Double
            let max = value["maxValue"] as? Double
            let currency = salary["currency"] as? String ?? ""
            if let min, let max {
                result.salary = "\(currency) \(Int(min))-\(Int(max))"
            }
        }
        result.description = jsonLD["description"] as? String ?? ""
    }

    // Fill gaps with Open Graph / meta tags
    if result.title.isEmpty {
        result.title = extractMetaContent(from: html, property: "og:title")
            ?? extractTag(from: html, tag: "title")
            ?? ""
    }
    if result.description.isEmpty {
        result.description = extractMetaContent(from: html, property: "og:description")
            ?? extractMetaContent(from: html, name: "description")
            ?? ""
    }
    if result.company.isEmpty {
        result.company = extractMetaContent(from: html, property: "og:site_name") ?? ""
    }

    // Strip HTML from description if present
    if result.description.contains("<") {
        result.description = result.description.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
    }

    // Known gated domains that returned truncated data
    if let domain = gatedDomain, !result.isComplete {
        throw JobURLError.loginRequired(domain)
    }

    return result
}

// MARK: - HTML Parsing Helpers

private func extractJSONLD(from html: String) -> [String: Any]? {
    let pattern = #"<script[^>]*type\s*=\s*"application/ld\+json"[^>]*>([\s\S]*?)</script>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..., in: html)
    let matches = regex.matches(in: html, range: range)

    for match in matches {
        guard let contentRange = Range(match.range(at: 1), in: html) else { continue }
        let jsonString = String(html[contentRange])
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
        // Check if it's a JobPosting
        if let type = obj["@type"] as? String, type == "JobPosting" {
            return obj
        }
        // Could be an array of schemas
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            if let posting = arr.first(where: { ($0["@type"] as? String) == "JobPosting" }) {
                return posting
            }
        }
    }
    return nil
}

private func extractMetaContent(from html: String, property: String) -> String? {
    let pattern = #"<meta[^>]*property\s*=\s*"\#(NSRegularExpression.escapedPattern(for: property))"[^>]*content\s*=\s*"([^"]*)"[^>]*/?\s*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..., in: html)
    guard let match = regex.firstMatch(in: html, range: range),
          let contentRange = Range(match.range(at: 1), in: html) else { return nil }
    let value = String(html[contentRange])
    return value.isEmpty ? nil : value
}

private func extractMetaContent(from html: String, name: String) -> String? {
    let pattern = #"<meta[^>]*name\s*=\s*"\#(NSRegularExpression.escapedPattern(for: name))"[^>]*content\s*=\s*"([^"]*)"[^>]*/?\s*>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..., in: html)
    guard let match = regex.firstMatch(in: html, range: range),
          let contentRange = Range(match.range(at: 1), in: html) else { return nil }
    let value = String(html[contentRange])
    return value.isEmpty ? nil : value
}

private func extractTag(from html: String, tag: String) -> String? {
    let pattern = "<\(tag)[^>]*>([^<]*)</\(tag)>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..., in: html)
    guard let match = regex.firstMatch(in: html, range: range),
          let contentRange = Range(match.range(at: 1), in: html) else { return nil }
    let value = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

// MARK: - Live Implementation

extension JobURLClient: DependencyKey {
    public static var liveValue: JobURLClient {
        JobURLClient(
            detectATS: { url in
                detectATSProvider(url)
            },
            fetchJobData: { url in
                let provider = detectATSProvider(url)

                switch provider {
                case .greenhouse:
                    if let params = parseGreenhouseURL(url) {
                        return try await fetchGreenhouseJob(boardToken: params.boardToken, jobID: params.jobID)
                    }
                    return try await fetchHTMLFallback(url: url)

                case .lever:
                    if let params = parseLeverURL(url) {
                        return try await fetchLeverJob(company: params.company, postingID: params.postingID)
                    }
                    return try await fetchHTMLFallback(url: url)

                case .unknown:
                    return try await fetchHTMLFallback(url: url)
                }
            }
        )
    }
}

extension JobURLClient: TestDependencyKey {
    public static let testValue = JobURLClient(
        detectATS: unimplemented("\(Self.self).detectATS"),
        fetchJobData: unimplemented("\(Self.self).fetchJobData")
    )
}

extension DependencyValues {
    public var jobURLClient: JobURLClient {
        get { self[JobURLClient.self] }
        set { self[JobURLClient.self] = newValue }
    }
}
