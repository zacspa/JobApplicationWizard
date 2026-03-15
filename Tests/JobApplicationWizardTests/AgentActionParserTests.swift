import XCTest
@testable import JobApplicationWizardCore

final class AgentActionParserTests: XCTestCase {

    // MARK: - AgentAction Codable

    func testUpdateFieldCodableRoundTrip() throws {
        let action = AgentAction.updateField(field: .company, value: "Acme Corp")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AgentAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testAddNoteCodableRoundTrip() throws {
        let action = AgentAction.addNote(title: "Phone Screen", body: "Went well, they asked about Swift concurrency")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AgentAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testAddContactCodableRoundTrip() throws {
        let action = AgentAction.addContact(name: "Jane Doe", title: "Engineering Manager", email: "jane@acme.com")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AgentAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testAddContactWithNilFields() throws {
        let action = AgentAction.addContact(name: "John", title: nil, email: nil)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AgentAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func testSetExcitementCodable() throws {
        let action = AgentAction.setExcitement(level: 5)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(AgentAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    // MARK: - AgentActionBlock

    func testAgentActionBlockCodableRoundTrip() throws {
        let block = AgentActionBlock(
            actions: [
                .updateField(field: .company, value: "Acme"),
                .addNote(title: "Note", body: "Body"),
                .setExcitement(level: 4),
            ],
            summary: "Updated company and added a note"
        )
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(AgentActionBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func testMalformedJSONDecodingFails() {
        let json = #"{"actions": [{"action": "unknownAction"}], "summary": "test"}"#
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(AgentActionBlock.self, from: data))
    }

    // MARK: - Text Action Extractor

    func testTextActionExtractorExtractsValidBlock() {
        let json = """
        {"actions": [{"action": "updateField", "field": "company", "value": "New Corp"}], "summary": "Updated company"}
        """
        let text = "Here are the changes:\n<actions>\(json)</actions>\nLet me know if that looks good."
        let block = TextActionExtractor.extract(from: text)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.actions.count, 1)
        XCTAssertEqual(block?.summary, "Updated company")
    }

    func testTextActionExtractorReturnsNilForNoMarkers() {
        let text = "I don't have any changes to make."
        XCTAssertNil(TextActionExtractor.extract(from: text))
    }

    func testTextActionExtractorRejectsCodeBlockMarkers() {
        let text = """
        Here's an example:
        ```
        <actions>{"actions": [{"action": "updateField", "field": "company", "value": "Test"}], "summary": "test"}</actions>
        ```
        """
        XCTAssertNil(TextActionExtractor.extract(from: text))
    }

    func testTextActionExtractorReturnsNilForMalformedJSON() {
        let text = "<actions>not valid json</actions>"
        XCTAssertNil(TextActionExtractor.extract(from: text))
    }

    func testTextActionExtractorStripsActions() {
        let json = """
        {"actions": [{"action": "updateField", "field": "company", "value": "New"}], "summary": "test"}
        """
        let text = "Before\n<actions>\(json)</actions>\nAfter"
        let stripped = TextActionExtractor.stripActions(from: text)
        XCTAssertFalse(stripped.contains("<actions>"))
        XCTAssertTrue(stripped.contains("Before"))
        XCTAssertTrue(stripped.contains("After"))
    }

    func testTextActionExtractorRejectsEmptyActions() {
        let json = #"{"actions": [], "summary": "nothing"}"#
        let text = "<actions>\(json)</actions>"
        XCTAssertNil(TextActionExtractor.extract(from: text))
    }

    // MARK: - Field Whitelist Validation

    func testAgentWritableFieldAllCasesComplete() {
        let expected: Set<String> = ["company", "title", "location", "salary", "url", "jobDescription", "resumeUsed", "coverLetter"]
        let actual = Set(AgentWritableField.allCases.map(\.rawValue))
        XCTAssertEqual(actual, expected)
    }
}
