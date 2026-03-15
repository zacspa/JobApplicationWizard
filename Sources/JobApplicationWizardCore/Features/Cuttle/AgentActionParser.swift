import Foundation

// MARK: - Agent Action

/// Actions the AI agent can propose. The jobId is inferred from CuttleContext, not included per-action.
public enum AgentAction: Codable, Equatable {
    case updateField(field: AgentWritableField, value: String)
    case setStatus(status: String)
    case addNote(title: String, body: String)
    case updateNote(matchTitle: String, title: String?, body: String?)
    case addContact(name: String, title: String?, email: String?)
    case updateContact(matchName: String, name: String?, title: String?, email: String?)
    case addInterview(round: Int, type: String, date: String?)
    case updateInterview(round: Int, type: String?, date: String?, interviewers: String?, notes: String?)
    case deleteNote(matchTitle: String)
    case deleteContact(matchName: String)
    case deleteInterview(round: Int)
    case addLabel(labelName: String)
    case removeLabel(labelName: String)
    case setExcitement(level: Int)

    // Custom Codable for clean JSON schema
    private enum CodingKeys: String, CodingKey {
        case action, field, value, status, title, body
        case name, email, round, type, date, labelName, level
        case matchTitle, matchName, interviewers, notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let action = try c.decode(String.self, forKey: .action)
        switch action {
        case "updateField":
            let field = try c.decode(AgentWritableField.self, forKey: .field)
            let value = try c.decode(String.self, forKey: .value)
            self = .updateField(field: field, value: value)
        case "setStatus":
            let status = try c.decode(String.self, forKey: .status)
            self = .setStatus(status: status)
        case "addNote":
            let title = try c.decode(String.self, forKey: .title)
            let body = try c.decode(String.self, forKey: .body)
            self = .addNote(title: title, body: body)
        case "updateNote":
            let matchTitle = try c.decode(String.self, forKey: .matchTitle)
            let title = try c.decodeIfPresent(String.self, forKey: .title)
            let body = try c.decodeIfPresent(String.self, forKey: .body)
            self = .updateNote(matchTitle: matchTitle, title: title, body: body)
        case "addContact":
            let name = try c.decode(String.self, forKey: .name)
            let title = try c.decodeIfPresent(String.self, forKey: .title)
            let email = try c.decodeIfPresent(String.self, forKey: .email)
            self = .addContact(name: name, title: title, email: email)
        case "updateContact":
            let matchName = try c.decode(String.self, forKey: .matchName)
            let name = try c.decodeIfPresent(String.self, forKey: .name)
            let title = try c.decodeIfPresent(String.self, forKey: .title)
            let email = try c.decodeIfPresent(String.self, forKey: .email)
            self = .updateContact(matchName: matchName, name: name, title: title, email: email)
        case "addInterview":
            let round = try c.decode(Int.self, forKey: .round)
            let type = try c.decode(String.self, forKey: .type)
            let date = try c.decodeIfPresent(String.self, forKey: .date)
            self = .addInterview(round: round, type: type, date: date)
        case "updateInterview":
            let round = try c.decode(Int.self, forKey: .round)
            let type = try c.decodeIfPresent(String.self, forKey: .type)
            let date = try c.decodeIfPresent(String.self, forKey: .date)
            let interviewers = try c.decodeIfPresent(String.self, forKey: .interviewers)
            let notes = try c.decodeIfPresent(String.self, forKey: .notes)
            self = .updateInterview(round: round, type: type, date: date, interviewers: interviewers, notes: notes)
        case "deleteNote":
            let matchTitle = try c.decode(String.self, forKey: .matchTitle)
            self = .deleteNote(matchTitle: matchTitle)
        case "deleteContact":
            let matchName = try c.decode(String.self, forKey: .matchName)
            self = .deleteContact(matchName: matchName)
        case "deleteInterview":
            let round = try c.decode(Int.self, forKey: .round)
            self = .deleteInterview(round: round)
        case "addLabel":
            let labelName = try c.decode(String.self, forKey: .labelName)
            self = .addLabel(labelName: labelName)
        case "removeLabel":
            let labelName = try c.decode(String.self, forKey: .labelName)
            self = .removeLabel(labelName: labelName)
        case "setExcitement":
            let level = try c.decode(Int.self, forKey: .level)
            self = .setExcitement(level: level)
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: c, debugDescription: "Unknown action: \(action)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .updateField(let field, let value):
            try c.encode("updateField", forKey: .action)
            try c.encode(field, forKey: .field)
            try c.encode(value, forKey: .value)
        case .setStatus(let status):
            try c.encode("setStatus", forKey: .action)
            try c.encode(status, forKey: .status)
        case .addNote(let title, let body):
            try c.encode("addNote", forKey: .action)
            try c.encode(title, forKey: .title)
            try c.encode(body, forKey: .body)
        case .updateNote(let matchTitle, let title, let body):
            try c.encode("updateNote", forKey: .action)
            try c.encode(matchTitle, forKey: .matchTitle)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(body, forKey: .body)
        case .addContact(let name, let title, let email):
            try c.encode("addContact", forKey: .action)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(email, forKey: .email)
        case .updateContact(let matchName, let name, let title, let email):
            try c.encode("updateContact", forKey: .action)
            try c.encode(matchName, forKey: .matchName)
            try c.encodeIfPresent(name, forKey: .name)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(email, forKey: .email)
        case .addInterview(let round, let type, let date):
            try c.encode("addInterview", forKey: .action)
            try c.encode(round, forKey: .round)
            try c.encode(type, forKey: .type)
            try c.encodeIfPresent(date, forKey: .date)
        case .updateInterview(let round, let type, let date, let interviewers, let notes):
            try c.encode("updateInterview", forKey: .action)
            try c.encode(round, forKey: .round)
            try c.encodeIfPresent(type, forKey: .type)
            try c.encodeIfPresent(date, forKey: .date)
            try c.encodeIfPresent(interviewers, forKey: .interviewers)
            try c.encodeIfPresent(notes, forKey: .notes)
        case .deleteNote(let matchTitle):
            try c.encode("deleteNote", forKey: .action)
            try c.encode(matchTitle, forKey: .matchTitle)
        case .deleteContact(let matchName):
            try c.encode("deleteContact", forKey: .action)
            try c.encode(matchName, forKey: .matchName)
        case .deleteInterview(let round):
            try c.encode("deleteInterview", forKey: .action)
            try c.encode(round, forKey: .round)
        case .addLabel(let labelName):
            try c.encode("addLabel", forKey: .action)
            try c.encode(labelName, forKey: .labelName)
        case .removeLabel(let labelName):
            try c.encode("removeLabel", forKey: .action)
            try c.encode(labelName, forKey: .labelName)
        case .setExcitement(let level):
            try c.encode("setExcitement", forKey: .action)
            try c.encode(level, forKey: .level)
        }
    }
}

// MARK: - Agent Action Block

/// A group of actions with a summary, as returned by the AI.
public struct AgentActionBlock: Codable, Equatable {
    public var actions: [AgentAction]
    public var summary: String

    public init(actions: [AgentAction], summary: String) {
        self.actions = actions
        self.summary = summary
    }
}

// MARK: - Pending Agent Review

/// Holds a proposed set of agent actions awaiting user approval.
public struct PendingAgentReview: Equatable {
    public var jobId: UUID
    public var actions: [AgentAction]
    public var summary: String
    public var accepted: Set<Int>  // indices of accepted actions; all selected by default

    public init(jobId: UUID, actions: [AgentAction], summary: String) {
        self.jobId = jobId
        self.actions = actions
        self.summary = summary
        self.accepted = Set(actions.indices)
    }
}

// MARK: - Agent Action Mode

public enum AgentActionMode: String, Codable, CaseIterable, Equatable, Sendable {
    case applyImmediately = "Apply Immediately"
    case requireApproval = "Require Approval"
}

// MARK: - Tool Use JSON Schema

/// The JSON Schema for the `apply_actions` tool, sent to Claude API.
public let applyActionsToolDefinition: [String: Any] = [
    "name": "apply_actions",
    "description": "Apply structured changes to the current job application. Only use this when the user asks you to modify, update, or add data to the job.",
    "input_schema": [
        "type": "object",
        "properties": [
            "actions": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "action": [
                            "type": "string",
                            "enum": ["updateField", "setStatus", "addNote", "updateNote", "deleteNote", "addContact", "updateContact", "deleteContact", "addInterview", "updateInterview", "deleteInterview", "addLabel", "removeLabel", "setExcitement"]
                        ],
                        "field": [
                            "type": "string",
                            "enum": ["company", "title", "location", "salary", "url", "jobDescription", "resumeUsed", "coverLetter"],
                            "description": "Required for updateField"
                        ],
                        "value": ["type": "string", "description": "Required for updateField"],
                        "status": ["type": "string", "description": "Required for setStatus"],
                        "title": ["type": "string"],
                        "body": ["type": "string"],
                        "matchTitle": ["type": "string", "description": "For updateNote: the current title of the note to update"],
                        "name": ["type": "string"],
                        "matchName": ["type": "string", "description": "For updateContact: the current name of the contact to update"],
                        "email": ["type": "string"],
                        "round": ["type": "integer", "description": "Round number; used to match existing interviews for updateInterview"],
                        "type": ["type": "string"],
                        "date": ["type": "string"],
                        "interviewers": ["type": "string", "description": "For updateInterview: interviewer names"],
                        "notes": ["type": "string", "description": "For updateInterview: interview notes"],
                        "labelName": ["type": "string"],
                        "level": ["type": "integer", "minimum": 1, "maximum": 5]
                    ],
                    "required": ["action"]
                ]
            ],
            "summary": [
                "type": "string",
                "description": "Brief summary of what these changes do"
            ]
        ],
        "required": ["actions", "summary"]
    ] as [String: Any]
]
