import Foundation

// MARK: - Cuttle Prompt Builder

/// Builds context-aware system prompts for each CuttleContext variant.
public enum CuttlePromptBuilder {

    /// Dispatches to the appropriate prompt builder based on context.
    public static func buildPrompt(
        context: CuttleContext,
        jobs: [JobApplication],
        profile: UserProfile,
        chatHistory: [ChatMessage]
    ) -> String {
        switch context {
        case .global:
            return buildGlobalPrompt(jobs: jobs, profile: profile, chatHistory: chatHistory)
        case .status(let status):
            return buildStatusPrompt(status: status, jobs: jobs, profile: profile, chatHistory: chatHistory)
        case .job(let id):
            if let job = jobs.first(where: { $0.id == id }) {
                return buildJobPrompt(job: job, profile: profile, chatHistory: chatHistory)
            }
            return buildGlobalPrompt(jobs: jobs, profile: profile, chatHistory: chatHistory)
        }
    }

    // MARK: - Global Prompt

    private static func buildGlobalPrompt(
        jobs: [JobApplication],
        profile: UserProfile,
        chatHistory: [ChatMessage]
    ) -> String {
        var sections: [String] = []

        sections.append("You are an expert career coach integrated into a job application tracker. The user is viewing their full job search dashboard.")

        appendProfileSection(to: &sections, profile: profile)

        // Jobs summary by status
        var statusSummary: [String] = ["Job Search Overview:"]
        for status in JobStatus.allCases {
            let statusJobs = jobs.filter { $0.status == status }
            if !statusJobs.isEmpty {
                let names = statusJobs.prefix(5).map { "\($0.displayCompany) \u{2013} \($0.displayTitle)" }
                let extra = statusJobs.count > 5 ? " (+\(statusJobs.count - 5) more)" : ""
                statusSummary.append("- \(status.rawValue) (\(statusJobs.count)): \(names.joined(separator: "; "))\(extra)")
            }
        }
        sections.append(statusSummary.joined(separator: "\n"))

        // Upcoming interviews across all jobs
        let now = Date()
        let upcoming = jobs.flatMap { job in
            job.interviews
                .filter { $0.date != nil && $0.date! > now && !$0.completed }
                .map { (job: job, interview: $0) }
        }
        .sorted { ($0.interview.date ?? .distantFuture) < ($1.interview.date ?? .distantFuture) }

        if !upcoming.isEmpty {
            let lines = upcoming.prefix(5).map { pair in
                let typeLabel = pair.interview.type.isEmpty ? "Round \(pair.interview.round)" : pair.interview.type
                return "- \(pair.job.displayCompany): \(typeLabel) \(pair.interview.date!.relativeString)"
            }
            sections.append("Upcoming Interviews:\n\(lines.joined(separator: "\n"))")
        }

        // Stats
        let active = jobs.filter { ![.rejected, .withdrawn, .offer].contains($0.status) }.count
        let offers = jobs.filter { $0.status == .offer }.count
        sections.append("Stats: \(jobs.count) total, \(active) active, \(offers) offers")

        appendChatHistory(to: &sections, chatHistory: chatHistory)
        sections.append("Help the user with their overall job search strategy. Be specific, actionable, and concise.")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Status Prompt

    private static func buildStatusPrompt(
        status: JobStatus,
        jobs: [JobApplication],
        profile: UserProfile,
        chatHistory: [ChatMessage]
    ) -> String {
        let statusJobs = jobs.filter { $0.status == status }
        var sections: [String] = []

        sections.append("You are an expert career coach. The user is focused on their \(status.rawValue) jobs (\(statusJobs.count) total).")

        appendProfileSection(to: &sections, profile: profile)

        // List jobs in this status
        if !statusJobs.isEmpty {
            let jobLines = statusJobs.map { job in
                var line = "- \(job.displayCompany) \u{2013} \(job.displayTitle)"
                if !job.location.isEmpty { line += " [\(job.location)]" }
                if !job.salary.isEmpty { line += " \(job.salary)" }
                line += " (excitement: \(job.excitement)/5)"
                return line
            }
            sections.append("\(status.rawValue) Jobs:\n\(jobLines.joined(separator: "\n"))")
        }

        // Status-specific context
        switch status {
        case .interview:
            let now = Date()
            let upcoming = statusJobs.flatMap { job in
                job.interviews
                    .filter { $0.date != nil && $0.date! > now && !$0.completed }
                    .map { (job: job, interview: $0) }
            }
            .sorted { ($0.interview.date ?? .distantFuture) < ($1.interview.date ?? .distantFuture) }
            if !upcoming.isEmpty {
                let lines = upcoming.prefix(8).map { pair in
                    let typeLabel = pair.interview.type.isEmpty ? "Round \(pair.interview.round)" : pair.interview.type
                    var line = "- \(pair.job.displayCompany): \(typeLabel) \(pair.interview.date!.relativeString)"
                    if !pair.interview.interviewers.isEmpty { line += " with \(pair.interview.interviewers)" }
                    return line
                }
                sections.append("Upcoming Interviews:\n\(lines.joined(separator: "\n"))")
            }
        case .rejected:
            // Include notes for pattern analysis
            let withNotes = statusJobs.filter { !$0.noteCards.isEmpty }
            if !withNotes.isEmpty {
                let noteLines = withNotes.prefix(5).map { job in
                    let noteSummary = job.noteCards.prefix(2).map { $0.title.isEmpty ? $0.body.prefix(100) : Substring($0.title) }
                    return "- \(job.displayCompany): \(noteSummary.joined(separator: "; "))"
                }
                sections.append("Notes from rejected applications:\n\(noteLines.joined(separator: "\n"))")
            }
        case .offer:
            let offerLines = statusJobs.map { job in
                var line = "- \(job.displayCompany) \u{2013} \(job.displayTitle)"
                if !job.salary.isEmpty { line += " \(job.salary)" }
                if !job.location.isEmpty { line += " [\(job.location)]" }
                return line
            }
            sections.append("Offers to compare:\n\(offerLines.joined(separator: "\n"))")
        default:
            break
        }

        appendChatHistory(to: &sections, chatHistory: chatHistory)

        let statusHints: [JobStatus: String] = [
            .wishlist: "Help the user evaluate and prioritize these prospects.",
            .applied: "Help the user follow up and prepare for next steps.",
            .phoneScreen: "Help the user prepare for phone screens and move forward.",
            .interview: "Help the user prepare for upcoming interviews, compare timelines, and strategize.",
            .offer: "Help the user compare offers, negotiate, and make a decision.",
            .rejected: "Help the user identify patterns, learn from feedback, and improve their approach.",
            .withdrawn: "Help the user reflect on why they withdrew and refine their search criteria.",
        ]
        sections.append(statusHints[status] ?? "Help the user with these applications.")
        sections.append("Be specific, actionable, and concise.")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Job Prompt

    /// Builds a rich prompt for a single job, adapted from JobDetailFeature.buildSystemPrompt.
    private static func buildJobPrompt(
        job: JobApplication,
        profile: UserProfile,
        chatHistory: [ChatMessage]
    ) -> String {
        var sections: [String] = []

        sections.append("You are an expert career coach integrated into a job application tracker.")

        appendProfileSection(to: &sections, profile: profile)

        // Job details
        var jobLines: [String] = [
            "Target Job: \(job.displayTitle) at \(job.displayCompany)",
            "Status: \(job.status.rawValue)",
        ]
        if !job.location.isEmpty { jobLines.append("Location: \(job.location)") }
        if !job.salary.isEmpty { jobLines.append("Salary: \(job.salary)") }
        if !job.labels.isEmpty { jobLines.append("Labels: \(job.labels.map(\.name).joined(separator: ", "))") }
        if job.excitement != 3 { jobLines.append("Excitement: \(job.excitement)/5") }
        if !job.resumeUsed.isEmpty { jobLines.append("Resume Version: \(job.resumeUsed)") }
        sections.append(jobLines.joined(separator: "\n"))

        // Job description
        sections.append("Job Description:\n\(job.jobDescription.isEmpty ? "Not provided" : job.jobDescription)")

        // Notes
        if !job.noteCards.isEmpty {
            let noteLines = job.noteCards.map { note in
                let body = note.body.count > 500 ? String(note.body.prefix(500)) + "..." : note.body
                let title = note.title.isEmpty ? "Untitled" : note.title
                return "- \(title): \(body)"
            }
            sections.append("Notes:\n\(noteLines.joined(separator: "\n"))")
        }

        // Contacts
        if !job.contacts.isEmpty {
            let contactLines = job.contacts.map { c in
                let titlePart = c.title.isEmpty ? "" : " (\(c.title))"
                let notesPart = c.notes.isEmpty ? "" : " \u{2014} \(c.notes)"
                return "- \(c.name)\(titlePart)\(notesPart)"
            }
            sections.append("Contacts:\n\(contactLines.joined(separator: "\n"))")
        }

        // Interview rounds
        if !job.interviews.isEmpty {
            let interviewLines = job.interviews.map { iv in
                var parts = "- Round \(iv.round): \(iv.type.isEmpty ? "TBD" : iv.type)"
                if let date = iv.date { parts += ", \(date.relativeString)" }
                if !iv.interviewers.isEmpty { parts += ", Interviewers: \(iv.interviewers)" }
                if !iv.notes.isEmpty { parts += ", Notes: \(iv.notes)" }
                if iv.completed { parts += " (completed)" }
                return parts
            }
            sections.append("Interview Rounds:\n\(interviewLines.joined(separator: "\n"))")
        }

        // Recent activity timeline
        var timeline: [String] = []
        timeline.append("- Added: \(job.dateAdded.relativeString)")
        if let applied = job.dateApplied {
            timeline.append("- Applied: \(applied.relativeString)")
        } else {
            timeline.append("- Applied: Not yet")
        }
        let now = Date()
        let upcoming = job.interviews
            .filter { $0.date != nil && $0.date! > now && !$0.completed }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        for iv in upcoming.prefix(3) {
            let typeLabel = iv.type.isEmpty ? "Round \(iv.round)" : "Round \(iv.round) (\(iv.type))"
            timeline.append("- \(typeLabel) scheduled \(iv.date!.relativeString)")
        }
        if let recentNote = job.noteCards.max(by: { $0.updatedAt < $1.updatedAt }),
           !recentNote.title.isEmpty {
            timeline.append("- Note '\(recentNote.title)' updated \(recentNote.updatedAt.relativeString)")
        }
        sections.append("Recent Activity:\n\(timeline.joined(separator: "\n"))")

        appendChatHistory(to: &sections, chatHistory: chatHistory)

        sections.append("Help the user with their application. Be specific, actionable, and concise.\nReference the data above when relevant; don't ask the user to repeat information they've already entered.")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Shared Helpers

    private static func appendProfileSection(to sections: inout [String], profile: UserProfile) {
        if !profile.name.isEmpty || !profile.resume.isEmpty {
            var lines: [String] = ["About the candidate:"]
            if !profile.name.isEmpty { lines.append("Name: \(profile.name)") }
            if !profile.currentTitle.isEmpty { lines.append("Current Title: \(profile.currentTitle)") }
            if !profile.location.isEmpty { lines.append("Location: \(profile.location)") }
            if !profile.skills.isEmpty { lines.append("Skills: \(profile.skills.joined(separator: ", "))") }
            if !profile.targetRoles.isEmpty { lines.append("Target Roles: \(profile.targetRoles.joined(separator: ", "))") }
            if !profile.preferredSalary.isEmpty { lines.append("Preferred Salary: \(profile.preferredSalary)") }
            lines.append("Work Preference: \(profile.workPreference.rawValue)")
            if !profile.summary.isEmpty { lines.append("Summary: \(profile.summary)") }
            if !profile.resume.isEmpty { lines.append("Resume:\n\(profile.resume)") }
            sections.append(lines.joined(separator: "\n"))
        }
    }

    private static func appendChatHistory(to sections: inout [String], chatHistory: [ChatMessage]) {
        if !chatHistory.isEmpty {
            let tail = chatHistory.suffix(6)
            let recap = tail.map { msg in
                let role = msg.role == .user ? "User" : "Assistant"
                let content = msg.content.count > 300 ? String(msg.content.prefix(300)) + "..." : msg.content
                return "\(role): \(content)"
            }
            sections.append("Previous conversation (\(chatHistory.count) messages):\n\(recap.joined(separator: "\n"))")
        }
    }
}
