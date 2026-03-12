import Foundation
import AppKit
import ComposableArchitecture
import UniformTypeIdentifiers

// MARK: - PersistenceClient

struct PersistenceClient {
    var loadJobs: @Sendable () async throws -> [JobApplication]
    var saveJobs: @Sendable ([JobApplication]) async throws -> Void
    var loadSettings: @Sendable () async throws -> AppSettings
    var saveSettings: @Sendable (AppSettings) async throws -> Void
    var exportCSV: @Sendable ([JobApplication]) -> String
    var showCSVSavePanel: @Sendable (String) async -> Void
    var showCSVOpenPanel: @Sendable () async -> String?   // returns CSV string if user picked a file
    var importCSV: @Sendable (String) -> [JobApplication]
}

// MARK: - CSV columns (complete dump)
// ID, Company, Title, URL, Status, DateAdded, DateApplied, Salary, Location,
// Excitement, IsFavorite, Labels, JobDescription, Notes, ResumeUsed, CoverLetter,
// Contacts, Interviews, HasPDF, PDFPath

private let csvHeader = "ID,Company,Title,URL,Status,DateAdded,DateApplied,Salary,Location,Excitement,IsFavorite,Labels,JobDescription,Notes,ResumeUsed,CoverLetter,Contacts,Interviews,HasPDF,PDFPath"

private let iso = ISO8601DateFormatter()

private func csvQuote(_ s: String) -> String {
    "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func jobToCSVRow(_ job: JobApplication) -> String {
    let labelsJSON = (try? String(data: JSONEncoder().encode(job.labels.map { $0.name }), encoding: .utf8)) ?? "[]"
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
        job.notes,
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
            } else if c == "\n" || c == "\r" {
                fields.append(field)
                field = ""
                // skip \r\n
                let next = text.index(after: i)
                if c == "\r", next < text.endIndex, text[next] == "\n" {
                    i = next
                }
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
    job.notes = col("Notes")
    job.resumeUsed = col("ResumeUsed")
    job.coverLetter = col("CoverLetter")
    job.hasPDF = col("HasPDF") == "true"
    let pdfPath = col("PDFPath")
    job.pdfPath = pdfPath.isEmpty ? nil : pdfPath

    // Labels — stored as JSON array of names, match against presets
    if let data = col("Labels").data(using: .utf8),
       let names = try? JSONDecoder().decode([String].self, from: data) {
        job.labels = names.compactMap { name in
            JobLabel.presets.first { $0.name == name }
            ?? (name.isEmpty ? nil : JobLabel(name: name, colorHex: "#8E8E93"))
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

    guard !job.company.isEmpty || !job.title.isEmpty else { return nil }
    return job
}

// MARK: - Live value

extension PersistenceClient: DependencyKey {
    static var liveValue: PersistenceClient {
        let appSupport: URL = {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("JobApplicationWizard", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }()
        let jobsURL = appSupport.appendingPathComponent("jobs.json")
        let settingsURL = appSupport.appendingPathComponent("settings.json")

        return PersistenceClient(
            loadJobs: {
                guard let data = try? Data(contentsOf: jobsURL) else { return [] }
                return try JSONDecoder().decode([JobApplication].self, from: data)
            },
            saveJobs: { jobs in
                let data = try JSONEncoder().encode(jobs)
                try data.write(to: jobsURL, options: .atomicWrite)
            },
            loadSettings: {
                guard let data = try? Data(contentsOf: settingsURL) else { return AppSettings() }
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
                await MainActor.run {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "job_applications.csv"
                    panel.allowedContentTypes = [UTType.commaSeparatedText]
                    if panel.runModal() == .OK, let url = panel.url {
                        try? csv.write(to: url, atomically: true, encoding: .utf8)
                    }
                }
            },
            showCSVOpenPanel: {
                await MainActor.run {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.plainText]
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a Job Application Wizard CSV file to import"
                    guard panel.runModal() == .OK, let url = panel.url else { return nil }
                    return try? String(contentsOf: url, encoding: .utf8)
                }
            },
            importCSV: { text in
                let rows = parseCSV(text)
                guard let headerRow = rows.first else { return [] }
                let headers = headerRow.map { $0.trimmingCharacters(in: .whitespaces) }
                return rows.dropFirst().compactMap { rowToJob($0, headers: headers) }
            }
        )
    }
}

extension DependencyValues {
    var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
