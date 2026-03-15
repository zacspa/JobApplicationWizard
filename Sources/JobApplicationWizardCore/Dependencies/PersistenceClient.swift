import Foundation
import AppKit
import ComposableArchitecture
import UniformTypeIdentifiers

// MARK: - PersistenceClient

public struct PersistenceClient {
    public var loadJobs: @Sendable () async throws -> [JobApplication]
    public var saveJobs: @Sendable ([JobApplication]) async throws -> Void
    public var loadSettings: @Sendable () async throws -> AppSettings
    public var saveSettings: @Sendable (AppSettings) async throws -> Void
    public var exportCSV: @Sendable ([JobApplication]) -> String
    public var showCSVSavePanel: @Sendable (String) async -> Void
    public var showCSVOpenPanel: @Sendable () async -> String?   // returns CSV string if user picked a file
    public var importCSV: @Sendable (String) -> [JobApplication]
    public var exportAllData: @Sendable ([JobApplication], AppSettings) -> Data
    public var importAllData: @Sendable (Data) throws -> AppDataExport
    public var showJSONSavePanel: @Sendable (Data) async -> Void
    public var showJSONOpenPanel: @Sendable () async -> Data?

    public init(
        loadJobs: @escaping @Sendable () async throws -> [JobApplication],
        saveJobs: @escaping @Sendable ([JobApplication]) async throws -> Void,
        loadSettings: @escaping @Sendable () async throws -> AppSettings,
        saveSettings: @escaping @Sendable (AppSettings) async throws -> Void,
        exportCSV: @escaping @Sendable ([JobApplication]) -> String,
        showCSVSavePanel: @escaping @Sendable (String) async -> Void,
        showCSVOpenPanel: @escaping @Sendable () async -> String?,
        importCSV: @escaping @Sendable (String) -> [JobApplication],
        exportAllData: @escaping @Sendable ([JobApplication], AppSettings) -> Data,
        importAllData: @escaping @Sendable (Data) throws -> AppDataExport,
        showJSONSavePanel: @escaping @Sendable (Data) async -> Void,
        showJSONOpenPanel: @escaping @Sendable () async -> Data?
    ) {
        self.loadJobs = loadJobs
        self.saveJobs = saveJobs
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.exportCSV = exportCSV
        self.showCSVSavePanel = showCSVSavePanel
        self.showCSVOpenPanel = showCSVOpenPanel
        self.importCSV = importCSV
        self.exportAllData = exportAllData
        self.importAllData = importAllData
        self.showJSONSavePanel = showJSONSavePanel
        self.showJSONOpenPanel = showJSONOpenPanel
    }
}

// MARK: - CSV columns (complete dump)
// ID, Company, Title, URL, Status, DateAdded, DateApplied, Salary, Location,
// Excitement, IsFavorite, Labels, JobDescription, NoteCards, ResumeUsed, CoverLetter,
// Contacts, Interviews, HasPDF, PDFPath

private let csvHeader = "ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,NoteCards,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath"

private let iso = ISO8601DateFormatter()

private func csvQuote(_ s: String) -> String {
    "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func jobToCSVRow(_ job: JobApplication) -> String {
    let labelsJSON = (try? String(data: JSONEncoder().encode(job.labels), encoding: .utf8)) ?? "[]"
    let noteCardsJSON = (try? String(data: JSONEncoder().encode(job.noteCards), encoding: .utf8)) ?? "[]"
    let contactsJSON = (try? String(data: JSONEncoder().encode(job.contacts), encoding: .utf8)) ?? "[]"
    let interviewsJSON = (try? String(data: JSONEncoder().encode(job.interviews), encoding: .utf8)) ?? "[]"

    return [
        job.id.uuidString,
        job.company,
        job.title,
        job.url,
        job.status.rawValue,
        iso.string(from: job.dateAdded),
        job.dateApplied.map { iso.string(from: $0) } ?? "",
        job.salary,
        job.location,
        "\(job.excitement)",
        job.isFavorite ? "true" : "false",
        labelsJSON,
        job.jobDescription,
        noteCardsJSON,
        job.resumeUsed,
        job.coverLetter,
        contactsJSON,
        interviewsJSON,
        job.hasPDF ? "true" : "false",
        job.pdfPath ?? ""
    ].map { csvQuote($0) }.joined(separator: ",")
}

// MARK: - CSV Parser (handles quoted fields with embedded commas/newlines)

private func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var fields: [String] = []
    var field = ""
    var inQuotes = false
    var i = text.startIndex

    while i < text.endIndex {
        let c = text[i]
        if inQuotes {
            if c == "\"" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "\"" {
                    field.append("\"")
                    i = text.index(after: next)
                    continue
                } else {
                    inQuotes = false
                }
            } else {
                field.append(c)
            }
        } else {
            if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(field)
                field = ""
            } else if c.isNewline {
                fields.append(field)
                field = ""
                if !fields.isEmpty {
                    rows.append(fields)
                    fields = []
                }
            } else {
                field.append(c)
            }
        }
        i = text.index(after: i)
    }
    // last field/row
    fields.append(field)
    if !fields.allSatisfy({ $0.isEmpty }) {
        rows.append(fields)
    }
    return rows
}

private func rowToJob(_ row: [String], headers: [String]) -> JobApplication? {
    func col(_ name: String) -> String {
        guard let idx = headers.firstIndex(of: name), idx < row.count else { return "" }
        return row[idx]
    }

    var job = JobApplication()

    if let id = UUID(uuidString: col("ID")) { job.id = id }
    job.company = col("Company")
    job.title = col("Title")
    job.url = col("URL")
    job.status = JobStatus(rawValue: col("Status")) ?? .wishlist
    job.dateAdded = iso.date(from: col("DateAdded")) ?? Date()
    job.dateApplied = iso.date(from: col("DateApplied"))
    job.salary = col("Salary")
    job.location = col("Location")
    job.excitement = Int(col("Excitement")) ?? 3
    job.isFavorite = col("IsFavorite") == "true"
    job.jobDescription = col("JobDescription")
    job.resumeUsed = col("ResumeUsed")
    job.coverLetter = col("CoverLetter")
    job.hasPDF = col("HasPDF") == "true"
    let pdfPath = col("PDFPath")
    job.pdfPath = pdfPath.isEmpty ? nil : pdfPath

    // Labels — try decoding as full JobLabel objects first, fall back to legacy name-only format
    if let data = col("Labels").data(using: .utf8) {
        if let labels = try? JSONDecoder().decode([JobLabel].self, from: data) {
            job.labels = labels
        } else if let names = try? JSONDecoder().decode([String].self, from: data) {
            job.labels = names.compactMap { name in
                JobLabel.presets.first { $0.name == name }
                ?? (name.isEmpty ? nil : JobLabel(name: name, colorHex: "#8E8E93"))
            }
        }
    }

    // Contacts — JSON encoded
    if let data = col("Contacts").data(using: .utf8),
       let contacts = try? JSONDecoder().decode([Contact].self, from: data) {
        job.contacts = contacts
    }

    // Interviews — JSON encoded
    if let data = col("Interviews").data(using: .utf8),
       let interviews = try? JSONDecoder().decode([InterviewRound].self, from: data) {
        job.interviews = interviews
    }

    // NoteCards — JSON encoded
    if let data = col("NoteCards").data(using: .utf8),
       let noteCards = try? JSONDecoder().decode([Note].self, from: data) {
        job.noteCards = noteCards
    }

    guard !job.company.isEmpty || !job.title.isEmpty else { return nil }
    return job
}

// MARK: - Live value

extension PersistenceClient: DependencyKey {
    public static var liveValue: PersistenceClient {
        let appSupport: URL = {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("JobApplicationWizard", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }()
        let jobsURL = appSupport.appendingPathComponent("jobs.json")
        let settingsURL = appSupport.appendingPathComponent("settings.json")

        let jobsBackupURL = appSupport.appendingPathComponent("jobs.backup.json")

        return PersistenceClient(
            loadJobs: {
                let fm = FileManager.default
                guard fm.fileExists(atPath: jobsURL.path) else { return [] }
                do {
                    let data = try Data(contentsOf: jobsURL)
                    return try JSONDecoder().decode([JobApplication].self, from: data)
                } catch {
                    // Primary file is corrupt; try the backup
                    if fm.fileExists(atPath: jobsBackupURL.path),
                       let backupData = try? Data(contentsOf: jobsBackupURL),
                       let backupJobs = try? JSONDecoder().decode([JobApplication].self, from: backupData) {
                        return backupJobs
                    }
                    throw error
                }
            },
            saveJobs: { jobs in
                // Create backup of existing file before overwriting
                let fm = FileManager.default
                if fm.fileExists(atPath: jobsURL.path) {
                    try? fm.removeItem(at: jobsBackupURL)
                    try? fm.copyItem(at: jobsURL, to: jobsBackupURL)
                }
                let data = try JSONEncoder().encode(jobs)
                try data.write(to: jobsURL, options: .atomicWrite)
            },
            loadSettings: {
                guard FileManager.default.fileExists(atPath: settingsURL.path) else { return AppSettings() }
                let data = try Data(contentsOf: settingsURL)
                return try JSONDecoder().decode(AppSettings.self, from: data)
            },
            saveSettings: { settings in
                let data = try JSONEncoder().encode(settings)
                try data.write(to: settingsURL, options: .atomicWrite)
            },
            exportCSV: { jobs in
                var lines = [csvHeader]
                for job in jobs.sorted(by: { $0.dateAdded > $1.dateAdded }) {
                    lines.append(jobToCSVRow(job))
                }
                return lines.joined(separator: "\n")
            },
            showCSVSavePanel: { csv in
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "job_applications.csv"
                        panel.allowedContentTypes = [UTType.commaSeparatedText]
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                try? csv.write(to: url, atomically: true, encoding: .utf8)
                            }
                            continuation.resume()
                        }
                    }
                }
            },
            showCSVOpenPanel: {
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.plainText]
                        panel.allowsMultipleSelection = false
                        panel.allowsOtherFileTypes = true
                        panel.message = "Select a Job Application Wizard CSV file to import"
                        panel.begin { response in
                            guard response == .OK, let url = panel.url else {
                                continuation.resume(returning: nil)
                                return
                            }
                            continuation.resume(returning: try? String(contentsOf: url, encoding: .utf8))
                        }
                    }
                }
            },
            importCSV: { text in
                let rows = parseCSV(text)
                guard let headerRow = rows.first else { return [] }
                let headers = headerRow.map { $0.trimmingCharacters(in: .whitespaces) }
                return rows.dropFirst().compactMap { rowToJob($0, headers: headers) }
            },
            exportAllData: { jobs, settings in
                let envelope = AppDataExport(jobs: jobs, settings: settings)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return (try? encoder.encode(envelope)) ?? Data()
            },
            importAllData: { data in
                let export = try JSONDecoder().decode(AppDataExport.self, from: data)
                guard export.version <= AppDataExport.currentVersion else {
                    throw NSError(
                        domain: "JobApplicationWizard",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "This backup was created by a newer version of the app (v\(export.version)). Please update Job Application Wizard to restore it."]
                    )
                }
                return export
            },
            showJSONSavePanel: { data in
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "job_wizard_backup.json"
                        panel.allowedContentTypes = [UTType.json]
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                try? data.write(to: url, options: .atomicWrite)
                            }
                            continuation.resume()
                        }
                    }
                }
            },
            showJSONOpenPanel: {
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [UTType.json]
                        panel.allowsMultipleSelection = false
                        panel.message = "Select a Job Application Wizard backup file to restore"
                        panel.begin { response in
                            guard response == .OK, let url = panel.url else {
                                continuation.resume(returning: nil)
                                return
                            }
                            continuation.resume(returning: try? Data(contentsOf: url))
                        }
                    }
                }
            }
        )
    }
}

extension PersistenceClient: TestDependencyKey {
    public static let testValue = PersistenceClient(
        loadJobs: unimplemented("\(Self.self).loadJobs", placeholder: []),
        saveJobs: unimplemented("\(Self.self).saveJobs", placeholder: ()),
        loadSettings: unimplemented("\(Self.self).loadSettings", placeholder: AppSettings()),
        saveSettings: unimplemented("\(Self.self).saveSettings", placeholder: ()),
        exportCSV: unimplemented("\(Self.self).exportCSV", placeholder: ""),
        showCSVSavePanel: unimplemented("\(Self.self).showCSVSavePanel", placeholder: ()),
        showCSVOpenPanel: unimplemented("\(Self.self).showCSVOpenPanel", placeholder: nil),
        importCSV: unimplemented("\(Self.self).importCSV", placeholder: []),
        exportAllData: unimplemented("\(Self.self).exportAllData", placeholder: Data()),
        importAllData: unimplemented("\(Self.self).importAllData", placeholder: AppDataExport(jobs: [], settings: AppSettings())),
        showJSONSavePanel: unimplemented("\(Self.self).showJSONSavePanel", placeholder: ()),
        showJSONOpenPanel: unimplemented("\(Self.self).showJSONOpenPanel", placeholder: nil)
    )
}

extension DependencyValues {
    public var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
