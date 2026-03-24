import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class AddJobImportTests: XCTestCase {

    // MARK: - Successful import (complete ATS data, skips enrichment)

    func testImportCompleteATSDataPopulatesFields() async {
        let scrapedData = ScrapedJobData(
            title: "Software Engineer",
            company: "Acme Corp",
            location: "San Francisco, CA",
            salary: "$150k-$200k",
            description: "Build amazing products",
            requirements: "5+ years experience",
            atsProvider: .greenhouse
        )

        var state = AddJobFeature.State()
        state.url = "https://boards.greenhouse.io/acme/jobs/123"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .greenhouse },
                fetchJobData: { _ in scrapedData }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.isImporting = false
            $0.importProgress = .done
            $0.entryMode = .manual
            $0.title = "Software Engineer"
            $0.company = "Acme Corp"
            $0.location = "San Francisco, CA"
            $0.salary = "$150k-$200k"
            $0.jobDescription = "Build amazing products\n\nRequirements:\n5+ years experience"
            $0.importedATSProvider = .greenhouse
        }
    }

    // MARK: - Import does not overwrite user-entered data

    func testImportDoesNotOverwriteUserEnteredFields() async {
        let scrapedData = ScrapedJobData(
            title: "Backend Engineer",
            company: "NewCo",
            location: "Remote",
            description: "Work on backend services",
            atsProvider: .lever
        )

        var state = AddJobFeature.State()
        state.url = "https://jobs.lever.co/newco/abc-123"
        state.company = "My Company"  // user already entered this
        state.title = "My Title"      // user already entered this

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .lever },
                fetchJobData: { _ in scrapedData }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.isImporting = false
            $0.importProgress = .done
            // User-entered fields preserved
            $0.company = "My Company"
            $0.title = "My Title"
            // Empty fields populated from scrape
            $0.location = "Remote"
            $0.jobDescription = "Work on backend services"
            $0.importedATSProvider = .lever
        }
    }

    // MARK: - Import with enrichment

    func testImportIncompleteDataTriggersEnrichment() async {
        let incompleteData = ScrapedJobData(
            title: "Engineer",
            company: "",
            location: "",
            description: "",
            atsProvider: .unknown,
            rawHTML: "<html><body>Some job</body></html>"
        )

        var state = AddJobFeature.State()
        state.url = "https://example.com/job/42"
        state.apiKey = "test-api-key"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .unknown },
                fetchJobData: { _ in incompleteData }
            )
            $0.claudeClient = ClaudeClient(
                chat: { _, _, _, _ in
                    let json = """
                    {"title":"Engineer","company":"Enriched Co","location":"New York","salary":"","description":"Great job description","requirements":""}
                    """
                    return (json, AITokenUsage(inputTokens: 100, outputTokens: 50), nil)
                }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.importProgress = .enriching
            $0.title = "Engineer"
            $0.importedATSProvider = .unknown
        }

        await store.receive(\.enrichmentResponse) {
            $0.isImporting = false
            $0.importProgress = .done
            $0.entryMode = .manual
            $0.company = "Enriched Co"
            $0.location = "New York"
            $0.jobDescription = "Great job description"
        }
    }

    // MARK: - Import skips enrichment when no API key

    func testImportSkipsEnrichmentWithoutAPIKey() async {
        let incompleteData = ScrapedJobData(
            title: "Designer",
            atsProvider: .unknown
        )

        var state = AddJobFeature.State()
        state.url = "https://example.com/job/42"
        state.apiKey = ""  // no API key

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .unknown },
                fetchJobData: { _ in incompleteData }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.isImporting = false
            $0.importProgress = .done
            $0.entryMode = .manual
            $0.title = "Designer"
            $0.importedATSProvider = .unknown
        }
    }

    // MARK: - Network error

    func testImportNetworkErrorShowsError() async {
        var state = AddJobFeature.State()
        state.url = "https://example.com/job/42"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .unknown },
                fetchJobData: { _ in throw JobURLError.networkError("Connection refused") }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.isImporting = false
            $0.importProgress = .idle
            $0.importError = "Network error: Connection refused"
        }
    }

    // MARK: - Invalid URL

    func testImportInvalidURLShowsError() async {
        var state = AddJobFeature.State()
        state.url = ""

        let store = TestStore(initialState: state) {
            AddJobFeature()
        }

        await store.send(.importURLTapped) {
            $0.importError = "Please enter a valid HTTP or HTTPS URL"
        }
    }

    // MARK: - Login required error

    func testImportLoginRequiredShowsError() async {
        var state = AddJobFeature.State()
        state.url = "https://www.linkedin.com/jobs/view/123"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .unknown },
                fetchJobData: { _ in throw JobURLError.loginRequired("linkedin.com") }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.isImporting = false
            $0.importProgress = .idle
            $0.importError = "linkedin.com requires login to view full job details. Paste the job description into the form instead."
        }
    }

    // MARK: - Dismiss error

    func testDismissImportError() async {
        var state = AddJobFeature.State()
        state.importError = "Some error"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        }

        await store.send(.dismissImportError) {
            $0.importError = nil
        }
    }

    // MARK: - AI Import from pasted text

    func testCreateFromPasteExtractsFields() async {
        var state = AddJobFeature.State()
        state.entryMode = .aiImport
        state.pastedText = "Software Engineer at Acme Corp\nSan Francisco, CA\n$150k-$200k\nBuild amazing products"
        state.apiKey = "test-key"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.claudeClient = ClaudeClient(
                chat: { _, _, _, _ in
                    let json = """
                    {"title":"Software Engineer","company":"Acme Corp","location":"San Francisco, CA","salary":"$150k-$200k","description":"Build amazing products","requirements":""}
                    """
                    return (json, AITokenUsage(inputTokens: 100, outputTokens: 50), nil)
                }
            )
        }

        await store.send(.createFromPasteTapped) {
            $0.isParsing = true
            $0.parseError = nil
        }

        await store.receive(\.parseResponse) {
            $0.isParsing = false
            $0.hasParsed = true
            $0.entryMode = .manual
            $0.title = "Software Engineer"
            $0.company = "Acme Corp"
            $0.location = "San Francisco, CA"
            $0.salary = "$150k-$200k"
            $0.jobDescription = "Build amazing products"
            $0.importedATSProvider = .unknown
        }
    }

    func testCreateFromPasteUsesACPWhenConnected() async {
        // Write to the shared in-memory store so the SharedReader in AddJobFeature picks it up
        @Shared(.inMemory("acpConnection")) var acpConnection = ACPConnectionState()
        $acpConnection.withLock {
            $0.aiProvider = .acpAgent
            $0.isConnected = true
        }

        var state = AddJobFeature.State()
        state.entryMode = .aiImport
        state.pastedText = "Designer at DesignCo, Remote"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.acpClient = ACPClient(
                connect: unimplemented("ACPClient.connect", placeholder: ""),
                disconnect: unimplemented("ACPClient.disconnect"),
                sendPrompt: { _, _ in
                    let json = """
                    {"title":"Designer","company":"DesignCo","location":"Remote","salary":"","description":"Design things","requirements":""}
                    """
                    return (json, .zero)
                },
                onUnexpectedDisconnect: { AsyncStream { $0.finish() } }
            )
        }

        await store.send(.createFromPasteTapped) {
            $0.isParsing = true
            $0.parseError = nil
        }

        await store.receive(\.parseResponse) {
            $0.isParsing = false
            $0.hasParsed = true
            $0.entryMode = .manual
            $0.title = "Designer"
            $0.company = "DesignCo"
            $0.location = "Remote"
            $0.jobDescription = "Design things"
            $0.importedATSProvider = .unknown
        }
    }

    func testCreateFromPasteFailureShowsError() async {
        var state = AddJobFeature.State()
        state.entryMode = .aiImport
        state.pastedText = "Some job text"
        state.apiKey = "test-key"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.claudeClient = ClaudeClient(
                chat: { _, _, _, _ in throw NSError(domain: "test", code: 500) }
            )
        }

        await store.send(.createFromPasteTapped) {
            $0.isParsing = true
            $0.parseError = nil
        }

        await store.receive(\.parseResponse) {
            $0.isParsing = false
            $0.parseError = "The operation couldn\u{2019}t be completed. (test error 500.)"
        }
    }

    func testDismissParseError() async {
        var state = AddJobFeature.State()
        state.parseError = "Some error"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        }

        await store.send(.dismissParseError) {
            $0.parseError = nil
        }
    }

    // MARK: - Enrichment failure fallback

    func testEnrichmentFailureShowsErrorButKeepsScrapedData() async {
        let partialData = ScrapedJobData(
            title: "Manager",
            company: "",
            atsProvider: .unknown,
            rawHTML: "<html></html>"
        )

        var state = AddJobFeature.State()
        state.url = "https://example.com/job/99"
        state.apiKey = "test-key"

        let store = TestStore(initialState: state) {
            AddJobFeature()
        } withDependencies: {
            $0.jobURLClient = JobURLClient(
                detectATS: { _ in .unknown },
                fetchJobData: { _ in partialData }
            )
            $0.claudeClient = ClaudeClient(
                chat: { _, _, _, _ in throw NSError(domain: "test", code: 500) }
            )
        }

        await store.send(.importURLTapped) {
            $0.isImporting = true
            $0.importError = nil
            $0.importProgress = .fetching
        }

        await store.receive(\.importResponse) {
            $0.importProgress = .enriching
            $0.title = "Manager"
            $0.importedATSProvider = .unknown
        }

        await store.receive(\.enrichmentResponse) {
            $0.isImporting = false
            $0.importProgress = .idle
            // Scraped data (title = "Manager") survives; only an error is added
            $0.importError = "Enrichment failed: The operation couldn\u{2019}t be completed. (test error 500.)"
        }
    }
}
