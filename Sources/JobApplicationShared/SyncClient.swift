import Foundation
import ComposableArchitecture

// MARK: - SyncClient

/// Dependency for syncing change events to/from Google Drive.
public struct SyncClient {
    /// Authenticate with Google (presents sign-in UI if needed).
    public var authenticate: @Sendable () async throws -> Void

    /// Check if user is currently authenticated.
    public var isAuthenticated: @Sendable () async -> Bool

    /// Sign out and clear stored credentials.
    public var signOut: @Sendable () -> Void

    /// Push a batch of change events to the remote store.
    public var pushBatch: @Sendable ([ChangeEvent]) async throws -> Void

    /// Pull all change events since a given timestamp (nil = all events).
    public var pullEvents: @Sendable (Date?) async throws -> [ChangeEvent]

    /// Upload a compacted snapshot and delete old batch files.
    public var compact: @Sendable (Data) async throws -> Void

    public init(
        authenticate: @escaping @Sendable () async throws -> Void,
        isAuthenticated: @escaping @Sendable () async -> Bool,
        signOut: @escaping @Sendable () -> Void,
        pushBatch: @escaping @Sendable ([ChangeEvent]) async throws -> Void,
        pullEvents: @escaping @Sendable (Date?) async throws -> [ChangeEvent],
        compact: @escaping @Sendable (Data) async throws -> Void
    ) {
        self.authenticate = authenticate
        self.isAuthenticated = isAuthenticated
        self.signOut = signOut
        self.pushBatch = pushBatch
        self.pullEvents = pullEvents
        self.compact = compact
    }
}

// MARK: - Dependency Registration

extension SyncClient: DependencyKey {
    /// Default: no-op (sync disabled until configured).
    public static let liveValue = SyncClient(
        authenticate: { },
        isAuthenticated: { false },
        signOut: { },
        pushBatch: { _ in },
        pullEvents: { _ in [] },
        compact: { _ in }
    )

    public static let testValue = SyncClient(
        authenticate: { },
        isAuthenticated: { false },
        signOut: { },
        pushBatch: { _ in },
        pullEvents: { _ in [] },
        compact: { _ in }
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
