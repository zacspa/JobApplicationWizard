import Foundation
import ComposableArchitecture

// MARK: - SharedPersistenceClient

public struct SharedPersistenceClient {
    public var loadJobs: @Sendable () async throws -> [JobApplication]
    public var saveJobs: @Sendable ([JobApplication]) async throws -> Void
    public var loadSettings: @Sendable () async throws -> AppSettings
    public var saveSettings: @Sendable (AppSettings) async throws -> Void
    public var exportAllData: @Sendable ([JobApplication], AppSettings) -> Data
    public var importAllData: @Sendable (Data) throws -> AppDataExport

    public init(
        loadJobs: @escaping @Sendable () async throws -> [JobApplication],
        saveJobs: @escaping @Sendable ([JobApplication]) async throws -> Void,
        loadSettings: @escaping @Sendable () async throws -> AppSettings,
        saveSettings: @escaping @Sendable (AppSettings) async throws -> Void,
        exportAllData: @escaping @Sendable ([JobApplication], AppSettings) -> Data,
        importAllData: @escaping @Sendable (Data) throws -> AppDataExport
    ) {
        self.loadJobs = loadJobs
        self.saveJobs = saveJobs
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.exportAllData = exportAllData
        self.importAllData = importAllData
    }
}
