import Foundation
@testable import JobApplicationWizardCore

extension JobApplication {
    static func mock(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        company: String = "Acme Corp",
        title: String = "Software Engineer",
        url: String = "https://acme.com/jobs/1",
        status: JobStatus = .wishlist,
        dateAdded: Date = Date(timeIntervalSinceReferenceDate: 0),
        dateApplied: Date? = nil,
        salary: String = "$120k",
        location: String = "Remote",
        jobDescription: String = "Build cool stuff",
        noteCards: [Note] = [],
        resumeUsed: String = "",
        coverLetter: String = "",
        labels: [JobLabel] = [],
        contacts: [Contact] = [],
        interviews: [InterviewRound] = [],
        isFavorite: Bool = false,
        excitement: Int = 3,
        hasPDF: Bool = false,
        pdfPath: String? = nil,
        chatHistory: [ChatMessage] = [],
        chatThreadStore: CuttleThreadStore? = nil,
        documents: [JobDocument] = []
    ) -> JobApplication {
        var job = JobApplication()
        job.id = id
        job.company = company
        job.title = title
        job.url = url
        job.status = status
        job.dateAdded = dateAdded
        job.dateApplied = dateApplied
        job.salary = salary
        job.location = location
        job.jobDescription = jobDescription
        job.noteCards = noteCards
        job.resumeUsed = resumeUsed
        job.coverLetter = coverLetter
        job.labels = labels
        job.contacts = contacts
        job.interviews = interviews
        job.isFavorite = isFavorite
        job.excitement = excitement
        job.hasPDF = hasPDF
        job.pdfPath = pdfPath
        if let store = chatThreadStore {
            job.chatThreadStore = store
        } else if !chatHistory.isEmpty {
            let thread = CuttleThread(messages: chatHistory)
            job.chatThreadStore = CuttleThreadStore(threads: [thread], activeThreadId: thread.id)
        }
        job.documents = documents
        return job
    }
}
