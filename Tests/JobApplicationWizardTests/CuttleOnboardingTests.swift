import ComposableArchitecture
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class CuttleOnboardingTests: XCTestCase {

    // MARK: - Start

    func testStartSetsActiveAndFirstStep() async {
        let store = TestStore(initialState: CuttleOnboardingFeature.State()) {
            CuttleOnboardingFeature()
        }

        await store.send(.start) {
            $0.isActive = true
            $0.currentStep = .meetCuttle
        }
    }

    // MARK: - Next Step

    func testNextStepAdvances() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .meetCuttle
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .expandCollapse
        }
    }

    func testNextStepToChatBasicsExpandsCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .expandCollapse
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .chatBasics
        }
        await store.receive(\.delegate.expandCuttle)
    }

    func testNextStepFromChatBasicsCollapsesCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .chatBasics
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep) {
            $0.currentStep = .dragToDock
        }
        await store.receive(\.delegate.collapseCuttle)
    }

    func testNextStepOnLastStepFinishes() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.aiReady = true  // skip aiSetup
        state.currentStep = .resize
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.nextStep)
        await store.receive(\.finish) {
            $0.isActive = false
        }
        await store.receive(\.delegate.completed)
    }

    // MARK: - Previous Step

    func testPreviousStepGoesBack() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .expandCollapse
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep) {
            $0.currentStep = .meetCuttle
        }
    }

    func testPreviousStepAtFirstDoesNothing() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .meetCuttle
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep)
    }

    func testPreviousStepFromChatBasicsCollapsesCuttle() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .chatBasics
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.previousStep) {
            $0.currentStep = .expandCollapse
        }
        await store.receive(\.delegate.collapseCuttle)
    }

    // MARK: - Skip All

    func testSkipAllDeactivatesAndSendsDelegate() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = .dragToDock
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.skipAll) {
            $0.isActive = false
        }
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - Finish

    func testFinishDeactivatesAndSendsDelegate() async {
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        let store = TestStore(initialState: state) { CuttleOnboardingFeature() }

        await store.send(.finish) {
            $0.isActive = false
        }
        await store.receive(\.delegate.completed)
    }

    // MARK: - Conditional AI Setup Step

    func testAiSetupIncludedWhenNotReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = false
        XCTAssertTrue(state.steps.contains(.aiSetup))
    }

    func testAiSetupExcludedWhenReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        XCTAssertFalse(state.steps.contains(.aiSetup))
    }

    func testStepCountWithAiReady() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        XCTAssertEqual(state.steps.count, 6)

        state.aiReady = false
        XCTAssertEqual(state.steps.count, 7)
    }

    // MARK: - State Properties

    func testIsFirstStep() {
        var state = CuttleOnboardingFeature.State()
        state.currentStep = .meetCuttle
        XCTAssertTrue(state.isFirstStep)

        state.currentStep = .expandCollapse
        XCTAssertFalse(state.isFirstStep)
    }

    func testIsLastStep() {
        var state = CuttleOnboardingFeature.State()
        state.aiReady = true
        state.currentStep = .resize
        XCTAssertTrue(state.isLastStep)

        state.currentStep = .meetCuttle
        XCTAssertFalse(state.isLastStep)
    }
}
