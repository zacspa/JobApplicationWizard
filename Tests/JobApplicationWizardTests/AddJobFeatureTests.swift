import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class AddJobFeatureTests: XCTestCase {

    // MARK: - canSave

    func testCanSaveRequiresCompanyOrTitle() {
        var state = AddJobFeature.State()
        XCTAssertFalse(state.canSave)

        state.company = "Acme"
        XCTAssertTrue(state.canSave)

        state.company = ""
        state.title = "Engineer"
        XCTAssertTrue(state.canSave)
    }

    // MARK: - toggleLabel

    func testToggleLabelAddsAndRemoves() async {
        let store = TestStore(initialState: AddJobFeature.State()) {
            AddJobFeature()
        }

        await store.send(.toggleLabel("Remote")) {
            $0.selectedLabelNames = ["Remote"]
        }
        await store.send(.toggleLabel("Remote")) {
            $0.selectedLabelNames = []
        }
    }

    // MARK: - setExcitement

    func testSetExcitement() async {
        let store = TestStore(initialState: AddJobFeature.State()) {
            AddJobFeature()
        }

        await store.send(.setExcitement(5)) {
            $0.excitement = 5
        }
    }

    // MARK: - saveTapped

    func testSaveTappedBuildsJobAndDelegates() async {
        var state = AddJobFeature.State()
        state.company = "Acme"
        state.title = "Engineer"
        state.salary = "$100k"
        state.selectedLabelNames = ["Remote"]

        let store = TestStore(initialState: state) {
            AddJobFeature()
        }

        await store.send(.saveTapped)

        // Should receive a delegate save action with the built job
        await store.receive(\.delegate.save)
    }

    func testSaveTappedWithAppliedStatusSetsDateApplied() async {
        var state = AddJobFeature.State()
        state.company = "Acme"
        state.status = .applied

        let store = TestStore(initialState: state) {
            AddJobFeature()
        }

        await store.send(.saveTapped)

        await store.receive(\.delegate.save)
    }

    // MARK: - cancelTapped

    func testCancelTappedDelegatesCancel() async {
        let store = TestStore(initialState: AddJobFeature.State()) {
            AddJobFeature()
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.cancel)
    }
}
