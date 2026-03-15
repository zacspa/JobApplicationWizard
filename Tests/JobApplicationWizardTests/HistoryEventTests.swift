import XCTest
@testable import JobApplicationWizardCore

final class HistoryEventTests: XCTestCase {

    // MARK: - Command Reverse

    func testUpdateFieldReversesCorrectly() {
        let cmd = HistoryCommand.updateField(
            jobId: UUID(), field: .company, oldValue: "Old", newValue: "New"
        )
        let reversed = cmd.reversed()
        if case .updateField(_, _, let oldValue, let newValue) = reversed {
            XCTAssertEqual(oldValue, "New")
            XCTAssertEqual(newValue, "Old")
        } else {
            XCTFail("Expected updateField")
        }
    }

    func testSetStatusReversesCorrectly() {
        let cmd = HistoryCommand.setStatus(jobId: UUID(), old: .wishlist, new: .applied)
        let reversed = cmd.reversed()
        if case .setStatus(_, let old, let new) = reversed {
            XCTAssertEqual(old, .applied)
            XCTAssertEqual(new, .wishlist)
        } else {
            XCTFail("Expected setStatus")
        }
    }

    func testToggleFavoriteReversesCorrectly() {
        let cmd = HistoryCommand.toggleFavorite(jobId: UUID(), old: false, new: true)
        let reversed = cmd.reversed()
        if case .toggleFavorite(_, let old, let new) = reversed {
            XCTAssertEqual(old, true)
            XCTAssertEqual(new, false)
        } else {
            XCTFail("Expected toggleFavorite")
        }
    }

    func testSetExcitementReversesCorrectly() {
        let cmd = HistoryCommand.setExcitement(jobId: UUID(), old: 3, new: 5)
        let reversed = cmd.reversed()
        if case .setExcitement(_, let old, let new) = reversed {
            XCTAssertEqual(old, 5)
            XCTAssertEqual(new, 3)
        } else {
            XCTFail("Expected setExcitement")
        }
    }

    func testAddLabelReversesToRemoveLabel() {
        let label = JobLabel(name: "Remote", colorHex: "#34C759")
        let cmd = HistoryCommand.addLabel(jobId: UUID(), label: label)
        let reversed = cmd.reversed()
        if case .removeLabel(_, let removedLabel) = reversed {
            XCTAssertEqual(removedLabel.name, "Remote")
        } else {
            XCTFail("Expected removeLabel")
        }
    }

    func testRemoveLabelReversesToAddLabel() {
        let label = JobLabel(name: "Remote", colorHex: "#34C759")
        let cmd = HistoryCommand.removeLabel(jobId: UUID(), label: label)
        let reversed = cmd.reversed()
        if case .addLabel(_, let addedLabel) = reversed {
            XCTAssertEqual(addedLabel.name, "Remote")
        } else {
            XCTFail("Expected addLabel")
        }
    }

    // MARK: - Compound Commands

    func testCompoundCommandReversesInOrder() {
        let id = UUID()
        let compound = HistoryCommand.compound([
            .updateField(jobId: id, field: .company, oldValue: "A", newValue: "B"),
            .setExcitement(jobId: id, old: 3, new: 5),
        ])
        let reversed = compound.reversed()
        if case .compound(let commands) = reversed {
            XCTAssertEqual(commands.count, 2)
            // Reversed order: excitement first, then company
            if case .setExcitement(_, let old, let new) = commands[0] {
                XCTAssertEqual(old, 5)
                XCTAssertEqual(new, 3)
            } else {
                XCTFail("Expected setExcitement first")
            }
            if case .updateField(_, _, let oldVal, let newVal) = commands[1] {
                XCTAssertEqual(oldVal, "B")
                XCTAssertEqual(newVal, "A")
            } else {
                XCTFail("Expected updateField second")
            }
        } else {
            XCTFail("Expected compound")
        }
    }

    // MARK: - Event Serialization

    func testHistoryEventCodableRoundTrip() throws {
        let event = HistoryEvent(
            label: "Changed company from 'Acme' to 'Acme Corp'",
            source: .user,
            command: .updateField(jobId: UUID(), field: .company, oldValue: "Acme", newValue: "Acme Corp")
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.label, event.label)
        XCTAssertEqual(decoded.source, event.source)
        XCTAssertEqual(decoded.command, event.command)
    }

    func testCompoundEventCodableRoundTrip() throws {
        let id = UUID()
        let event = HistoryEvent(
            label: "AI: Updated multiple fields",
            source: .agent,
            command: .compound([
                .updateField(jobId: id, field: .title, oldValue: "Dev", newValue: "Senior Dev"),
                .addNote(jobId: id, noteId: UUID()),
            ])
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryEvent.self, from: data)

        XCTAssertEqual(decoded.source, .agent)
        if case .compound(let cmds) = decoded.command {
            XCTAssertEqual(cmds.count, 2)
        } else {
            XCTFail("Expected compound command")
        }
    }

    // MARK: - AgentWritableField

    func testAgentWritableFieldExcludesIdAndDates() {
        let fields = AgentWritableField.allCases.map(\.rawValue)
        XCTAssertFalse(fields.contains("id"))
        XCTAssertFalse(fields.contains("dateAdded"))
        XCTAssertFalse(fields.contains("chatHistory"))
        XCTAssertFalse(fields.contains("documents"))
        XCTAssertTrue(fields.contains("company"))
        XCTAssertTrue(fields.contains("title"))
        XCTAssertTrue(fields.contains("jobDescription"))
    }
}
