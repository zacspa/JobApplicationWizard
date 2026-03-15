import Foundation

// MARK: - Text Action Extractor

/// Fallback parser for ACP responses: extracts `<actions>...</actions>` JSON blocks from text.
public enum TextActionExtractor {

    /// Attempts to extract an AgentActionBlock from text containing `<actions>...</actions>` markers.
    /// Returns nil if no valid action block is found.
    public static func extract(from text: String) -> AgentActionBlock? {
        guard let range = findActionsRange(in: text) else { return nil }

        let jsonString = String(text[range])
        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            let block = try JSONDecoder().decode(AgentActionBlock.self, from: data)
            guard !block.actions.isEmpty else { return nil }
            return block
        } catch {
            return nil
        }
    }

    /// Strips `<actions>...</actions>` markers from the text, returning the clean response.
    public static func stripActions(from text: String) -> String {
        guard let openRange = text.range(of: "<actions>"),
              let closeRange = text.range(of: "</actions>") else {
            return text
        }
        var result = text
        let fullRange = openRange.lowerBound..<closeRange.upperBound
        result.removeSubrange(fullRange)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    /// Finds the JSON content between `<actions>` and `</actions>` tags,
    /// rejecting matches that appear inside code blocks.
    private static func findActionsRange(in text: String) -> Range<String.Index>? {
        // Reject if the markers are inside a code block
        let codeBlockPattern = "```[\\s\\S]*?```"
        if let codeRegex = try? NSRegularExpression(pattern: codeBlockPattern),
           let _ = codeRegex.firstMatch(
               in: text,
               range: NSRange(text.startIndex..., in: text)
           ) {
            // Check if <actions> appears within a code block
            let matches = codeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let block = text[range]
                    if block.contains("<actions>") {
                        return nil
                    }
                }
            }
        }

        guard let openRange = text.range(of: "<actions>"),
              let closeRange = text.range(of: "</actions>") else {
            return nil
        }

        let jsonStart = openRange.upperBound
        let jsonEnd = closeRange.lowerBound

        guard jsonStart < jsonEnd else { return nil }

        return jsonStart..<jsonEnd
    }
}
