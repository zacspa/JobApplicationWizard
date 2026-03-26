import Foundation
import ComposableArchitecture
import JobApplicationShared

// MARK: - Dependency Registration

extension SharedPersistenceClient: @retroactive DependencyKey {
    public static let liveValue = SharedPersistenceClient(
        loadJobs: {
            let url = Self.jobsURL
            print("[Persistence] Loading jobs from: \(url.path)")
            print("[Persistence] File exists: \(FileManager.default.fileExists(atPath: url.path))")
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            print("[Persistence] Data size: \(data.count) bytes")
            let jobs = try JSONDecoder().decode([JobApplication].self, from: data)
            print("[Persistence] Loaded \(jobs.count) jobs")
            return jobs
        },
        saveJobs: { jobs in
            let url = Self.jobsURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: url, options: .atomic)
        },
        loadSettings: {
            let url = Self.settingsURL
            guard FileManager.default.fileExists(atPath: url.path) else { return AppSettings() }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        },
        saveSettings: { settings in
            let url = Self.settingsURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: .atomic)
        },
        exportAllData: { jobs, settings in
            let export = AppDataExport(
                jobs: jobs,
                settings: settings
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return (try? encoder.encode(export)) ?? Data()
        },
        importAllData: { data in
            try JSONDecoder().decode(AppDataExport.self, from: data)
        }
    )

    public static let testValue = SharedPersistenceClient(
        loadJobs: { [] },
        saveJobs: { _ in },
        loadSettings: { AppSettings() },
        saveSettings: { _ in },
        exportAllData: { _, _ in Data() },
        importAllData: { data in
            try JSONDecoder().decode(AppDataExport.self, from: data)
        }
    )
}

extension DependencyValues {
    var sharedPersistence: SharedPersistenceClient {
        get { self[SharedPersistenceClient.self] }
        set { self[SharedPersistenceClient.self] = newValue }
    }
}

// MARK: - File Locations

extension SharedPersistenceClient {
    /// Uses app group container for sharing with widget and share extension.
    private static let containerURL: URL = {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.zsparks.JobApplicationWizard"
        ) {
            return groupURL
        }
        // Fallback to Application Support
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JobApplicationWizard")
    }()

    static let jobsURL = containerURL.appendingPathComponent("jobs.json")
    static let settingsURL = containerURL.appendingPathComponent("settings.json")
}
