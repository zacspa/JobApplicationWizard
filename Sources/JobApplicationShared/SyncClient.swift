import Foundation
import ComposableArchitecture

// MARK: - SyncClient

/// Dependency for syncing change events to/from Google Drive.
public struct SyncClient {
    /// Authenticate with Google (presents sign-in UI if needed).
    public var authenticate: @Sendable () async throws -> Void

    /// Check if user is currently authenticated.
    public var isAuthenticated: @Sendable () -> Bool

    /// Sign out and clear stored credentials.
    public var signOut: @Sendable () -> Void

    /// Push a single change event to the remote changelog.
    public var pushEvent: @Sendable (ChangeEvent) async throws -> Void

    /// Pull all change events since a given timestamp (nil = all events).
    public var pullEvents: @Sendable (Date?) async throws -> [ChangeEvent]

    /// Push a full state snapshot for periodic compaction.
    public var pushSnapshot: @Sendable (Data) async throws -> Void

    /// Pull the latest full state snapshot.
    public var pullSnapshot: @Sendable () async throws -> Data?

    public init(
        authenticate: @escaping @Sendable () async throws -> Void,
        isAuthenticated: @escaping @Sendable () -> Bool,
        signOut: @escaping @Sendable () -> Void,
        pushEvent: @escaping @Sendable (ChangeEvent) async throws -> Void,
        pullEvents: @escaping @Sendable (Date?) async throws -> [ChangeEvent],
        pushSnapshot: @escaping @Sendable (Data) async throws -> Void,
        pullSnapshot: @escaping @Sendable () async throws -> Data?
    ) {
        self.authenticate = authenticate
        self.isAuthenticated = isAuthenticated
        self.signOut = signOut
        self.pushEvent = pushEvent
        self.pullEvents = pullEvents
        self.pushSnapshot = pushSnapshot
        self.pullSnapshot = pullSnapshot
    }
}

// MARK: - Dependency Registration

extension SyncClient: DependencyKey {
    /// Default: no-op (sync disabled until configured).
    public static let liveValue = SyncClient(
        authenticate: { },
        isAuthenticated: { false },
        signOut: { },
        pushEvent: { _ in },
        pullEvents: { _ in [] },
        pushSnapshot: { _ in },
        pullSnapshot: { nil }
    )

    public static let testValue = SyncClient(
        authenticate: { },
        isAuthenticated: { false },
        signOut: { },
        pushEvent: { _ in },
        pullEvents: { _ in [] },
        pushSnapshot: { _ in },
        pullSnapshot: { nil }
    )
}

public extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}

// MARK: - Sync Errors

public enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case encodingError
    case decodingError(Error)
    case driveAPIError(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to Google Drive."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError:
            return "Failed to encode sync data."
        case .decodingError(let error):
            return "Failed to decode sync data: \(error.localizedDescription)"
        case .driveAPIError(let message):
            return "Google Drive error: \(message)"
        }
    }
}
