import Foundation
import ComposableArchitecture

// MARK: - HistoryClient

/// Side-channel history persistence using append-only NDJSON with periodic checkpoints.
/// Lives outside the TCA state tree; queried on-demand via effects.
public struct HistoryClient {
    public var record: @Sendable (HistoryEvent) async -> Void
    public var recentEvents: @Sendable (Int) async -> [HistoryEvent]
    public var eventCount: @Sendable () async -> Int
    public var undoLast: @Sendable () async throws -> HistoryCommand
    public var revertTo: @Sendable (UUID) async throws -> [HistoryCommand]
    public var checkpoint: @Sendable ([JobApplication]) async -> Void
    public var loadCheckpoint: @Sendable () async -> [JobApplication]?

    public init(
        record: @escaping @Sendable (HistoryEvent) async -> Void,
        recentEvents: @escaping @Sendable (Int) async -> [HistoryEvent],
        eventCount: @escaping @Sendable () async -> Int,
        undoLast: @escaping @Sendable () async throws -> HistoryCommand,
        revertTo: @escaping @Sendable (UUID) async throws -> [HistoryCommand],
        checkpoint: @escaping @Sendable ([JobApplication]) async -> Void,
        loadCheckpoint: @escaping @Sendable () async -> [JobApplication]?
    ) {
        self.record = record
        self.recentEvents = recentEvents
        self.eventCount = eventCount
        self.undoLast = undoLast
        self.revertTo = revertTo
        self.checkpoint = checkpoint
        self.loadCheckpoint = loadCheckpoint
    }
}

// MARK: - Live Implementation

/// Actor-isolated storage for the history log.
private actor HistoryStorage {
    private let historyURL: URL
    private let checkpointURL: URL
    private var events: [HistoryEvent] = []
    private let maxEvents = 500
    private let checkpointInterval = 50
    private var eventsSinceCheckpoint = 0

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("JobApplicationWizard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        historyURL = dir.appendingPathComponent("history.ndjson")
        checkpointURL = dir.appendingPathComponent("history-checkpoint.json")

        // Load existing events
        if let data = try? Data(contentsOf: historyURL) {
            let lines = String(data: data, encoding: .utf8)?.components(separatedBy: "\n") ?? []
            for line in lines where !line.isEmpty {
                if let lineData = line.data(using: .utf8),
                   let event = try? decoder.decode(HistoryEvent.self, from: lineData) {
                    events.append(event)
                }
            }
        }
    }

    func record(_ event: HistoryEvent) {
        events.append(event)

        // Prune to rolling window
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }

        // Append to NDJSON
        if let data = try? encoder.encode(event),
           let line = String(data: data, encoding: .utf8) {
            let appendData = (line + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: historyURL.path) {
                if let handle = try? FileHandle(forWritingTo: historyURL) {
                    handle.seekToEndOfFile()
                    handle.write(appendData)
                    handle.closeFile()
                }
            } else {
                try? appendData.write(to: historyURL)
            }
        }

        eventsSinceCheckpoint += 1
    }

    var needsCheckpoint: Bool {
        eventsSinceCheckpoint >= checkpointInterval
    }

    func recentEvents(_ count: Int) -> [HistoryEvent] {
        Array(events.suffix(count))
    }

    var count: Int { events.count }

    func undoLast() throws -> HistoryCommand {
        guard let last = events.last else {
            throw HistoryError.noEventsToUndo
        }
        return last.command.reversed()
    }

    func revertTo(_ eventId: UUID) throws -> [HistoryCommand] {
        guard let targetIndex = events.firstIndex(where: { $0.id == eventId }) else {
            throw HistoryError.eventNotFound
        }
        // Return reversed commands for all events after the target, in reverse order
        let eventsToRevert = events[(targetIndex + 1)...]
        return eventsToRevert.reversed().map { $0.command.reversed() }
    }

    func saveCheckpoint(_ jobs: [JobApplication]) {
        eventsSinceCheckpoint = 0
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(jobs) {
            try? data.write(to: checkpointURL)
        }
    }

    func loadCheckpoint() -> [JobApplication]? {
        guard let data = try? Data(contentsOf: checkpointURL) else { return nil }
        return try? JSONDecoder().decode([JobApplication].self, from: data)
    }
}

public enum HistoryError: LocalizedError {
    case noEventsToUndo
    case eventNotFound

    public var errorDescription: String? {
        switch self {
        case .noEventsToUndo: return "No events to undo."
        case .eventNotFound: return "Event not found in history."
        }
    }
}

extension HistoryClient: DependencyKey {
    public static var liveValue: HistoryClient {
        let storage = HistoryStorage()
        return HistoryClient(
            record: { event in
                await storage.record(event)
                if await storage.needsCheckpoint {
                    // Checkpoint will be triggered by the caller with current jobs
                }
            },
            recentEvents: { count in
                await storage.recentEvents(count)
            },
            eventCount: {
                await storage.count
            },
            undoLast: {
                try await storage.undoLast()
            },
            revertTo: { eventId in
                try await storage.revertTo(eventId)
            },
            checkpoint: { jobs in
                await storage.saveCheckpoint(jobs)
            },
            loadCheckpoint: {
                await storage.loadCheckpoint()
            }
        )
    }
}

extension HistoryClient: TestDependencyKey {
    public static let testValue = HistoryClient(
        record: unimplemented("\(Self.self).record"),
        recentEvents: unimplemented("\(Self.self).recentEvents", placeholder: []),
        eventCount: unimplemented("\(Self.self).eventCount", placeholder: 0),
        undoLast: unimplemented("\(Self.self).undoLast"),
        revertTo: unimplemented("\(Self.self).revertTo", placeholder: []),
        checkpoint: unimplemented("\(Self.self).checkpoint"),
        loadCheckpoint: unimplemented("\(Self.self).loadCheckpoint", placeholder: nil)
    )
}

extension DependencyValues {
    public var historyClient: HistoryClient {
        get { self[HistoryClient.self] }
        set { self[HistoryClient.self] = newValue }
    }
}
