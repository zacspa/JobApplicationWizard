import XCTest
@testable import JobApplicationWizardCore

final class JobURLClientTests: XCTestCase {

    // MARK: - ATS Detection

    func testDetectsGreenhouseFromBoardsURL() {
        let client = JobURLClient.liveValue
        let url = URL(string: "https://boards.greenhouse.io/acme/jobs/12345")!
        XCTAssertEqual(client.detectATS(url), .greenhouse)
    }

    func testDetectsGreenhouseFromJobBoardsSubdomain() {
        let client = JobURLClient.liveValue
        let url = URL(string: "https://job-boards.greenhouse.io/acme/jobs/67890")!
        XCTAssertEqual(client.detectATS(url), .greenhouse)
    }

    func testDetectsLeverFromJobsURL() {
        let client = JobURLClient.liveValue
        let url = URL(string: "https://jobs.lever.co/acme/abc-def-123")!
        XCTAssertEqual(client.detectATS(url), .lever)
    }

    func testDetectsUnknownForGenericURL() {
        let client = JobURLClient.liveValue
        let url = URL(string: "https://careers.example.com/job/12345")!
        XCTAssertEqual(client.detectATS(url), .unknown)
    }

    func testDetectsGreenhouseFromQueryParam() {
        let client = JobURLClient.liveValue
        let url = URL(string: "https://example.com/apply?gh_jid=12345")!
        XCTAssertEqual(client.detectATS(url), .greenhouse)
    }

    // MARK: - ScrapedJobData

    func testIsCompleteWhenAllFieldsPresent() {
        let data = ScrapedJobData(
            title: "Engineer",
            company: "Acme",
            location: "Remote",
            description: "Build things"
        )
        XCTAssertTrue(data.isComplete)
    }

    func testIsNotCompleteWhenTitleMissing() {
        let data = ScrapedJobData(
            company: "Acme",
            location: "Remote",
            description: "Build things"
        )
        XCTAssertFalse(data.isComplete)
    }

    func testIsNotCompleteWhenDescriptionMissing() {
        let data = ScrapedJobData(
            title: "Engineer",
            company: "Acme",
            location: "Remote"
        )
        XCTAssertFalse(data.isComplete)
    }

    // MARK: - Login Wall Detection

    func testLoginRequiredErrorDescription() {
        let error = JobURLError.loginRequired("linkedin.com")
        XCTAssertEqual(
            error.errorDescription,
            "linkedin.com requires login to view full job details. Paste the job description into the form instead."
        )
    }

    func testKnownGatedDomainDetection() {
        XCTAssertEqual(
            matchGatedDomain(URL(string: "https://www.linkedin.com/jobs/view/123")!),
            "linkedin.com"
        )
        XCTAssertEqual(
            matchGatedDomain(URL(string: "https://indeed.com/viewjob?jk=abc")!),
            "indeed.com"
        )
        XCTAssertNil(
            matchGatedDomain(URL(string: "https://careers.example.com/job/42")!)
        )
    }

    func testRedirectToLoginDetected() {
        let authwallURL = URL(string: "https://www.linkedin.com/authwall?trk=job")!
        XCTAssertTrue(isLoginRedirect(authwallURL))

        let signinURL = URL(string: "https://example.com/signin?next=/job/42")!
        XCTAssertTrue(isLoginRedirect(signinURL))

        let normalURL = URL(string: "https://example.com/jobs/42")!
        XCTAssertFalse(isLoginRedirect(normalURL))
    }

    func testLoginWallHTMLMarkers() {
        let gatedHTML = "<html><body><div id=\"auth-wall\">Sign in to continue</div></body></html>"
        XCTAssertTrue(containsLoginWallMarkers(gatedHTML))

        let normalHTML = "<html><body><h1>Software Engineer</h1><p>Great job</p></body></html>"
        XCTAssertFalse(containsLoginWallMarkers(normalHTML))
    }

    // MARK: - Mock Fetch

    func testMockFetchReturnsExpectedData() async throws {
        let mockClient = JobURLClient(
            detectATS: { _ in .greenhouse },
            fetchJobData: { _ in
                ScrapedJobData(
                    title: "Software Engineer",
                    company: "TestCo",
                    location: "San Francisco",
                    salary: "$150k-$200k",
                    description: "Build amazing products",
                    atsProvider: .greenhouse
                )
            }
        )

        let url = URL(string: "https://boards.greenhouse.io/testco/jobs/123")!
        let result = try await mockClient.fetchJobData(url)

        XCTAssertEqual(result.title, "Software Engineer")
        XCTAssertEqual(result.company, "TestCo")
        XCTAssertEqual(result.location, "San Francisco")
        XCTAssertEqual(result.atsProvider, .greenhouse)
        XCTAssertTrue(result.isComplete)
    }

    func testMockFetchThrowsError() async {
        let mockClient = JobURLClient(
            detectATS: { _ in .unknown },
            fetchJobData: { _ in
                throw JobURLError.networkError("Connection refused")
            }
        )

        let url = URL(string: "https://example.com/job/123")!
        do {
            _ = try await mockClient.fetchJobData(url)
            XCTFail("Expected error to be thrown")
        } catch let error as JobURLError {
            XCTAssertEqual(error, .networkError("Connection refused"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
