import ComposableArchitecture
import Foundation

@Reducer
public struct CuttleOnboardingFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentStep: OnboardingStep = .meetCuttle
        public var isActive: Bool = false
        public var aiReady: Bool = false

        public var steps: [OnboardingStep] {
            OnboardingStep.allCases.filter { step in
                if step == .aiSetup { return !aiReady }
                return true
            }
        }

        public var currentStepIndex: Int {
            steps.firstIndex(of: currentStep) ?? 0
        }

        public var isFirstStep: Bool {
            currentStepIndex == 0
        }

        public var isLastStep: Bool {
            currentStepIndex == steps.count - 1
        }

        public init() {}
    }

    public enum OnboardingStep: String, CaseIterable, Equatable {
        case meetCuttle
        case expandCollapse
        case chatBasics
        case dragToDock
        case carryOrFresh
        case resize
        case aiSetup

        public var title: String {
            switch self {
            case .meetCuttle: return "Meet Cuttle"
            case .expandCollapse: return "Expand / Collapse"
            case .chatBasics: return "Chat Basics"
            case .dragToDock: return "Drag to Dock"
            case .carryOrFresh: return "Carry or Fresh"
            case .resize: return "Resize"
            case .aiSetup: return "AI Setup"
            }
        }

        public var body: String {
            switch self {
            case .meetCuttle:
                return "This is Cuttle, your AI job search companion. It lives in your workspace and adapts to what you're working on."
            case .expandCollapse:
                return "Double-click to open the chat window. Double-click again, press Escape, or click outside to close it."
            case .chatBasics:
                return "Type a question or click a suggestion chip. Cuttle's answers are scoped to its current context."
            case .dragToDock:
                return "Drag Cuttle onto any status column, job card, or the All filter to change its context."
            case .carryOrFresh:
                return "When switching context with an active conversation, Cuttle asks whether to carry the conversation or start fresh."
            case .resize:
                return "Drag the corner handle to resize the chat window."
            case .aiSetup:
                return "Set up your AI provider in Settings to get started."
            }
        }

        public var spotlightTarget: SpotlightTarget {
            switch self {
            case .meetCuttle: return .blob
            case .expandCollapse: return .blob
            case .chatBasics: return .chatWindow
            case .dragToDock: return .dockTargets
            case .carryOrFresh: return .none
            case .resize: return .chatWindow
            case .aiSetup: return .none
            }
        }
    }

    public enum SpotlightTarget: Equatable {
        case blob
        case chatWindow
        case dockTargets
        case none
    }

    public enum Action {
        case start
        case nextStep
        case previousStep
        case skipAll
        case finish
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case completed
            case dismissed
            case expandCuttle
            case collapseCuttle
            case openSettings
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                state.isActive = true
                state.currentStep = state.steps.first ?? .meetCuttle
                return .none

            case .nextStep:
                let steps = state.steps
                let currentIndex = state.currentStepIndex
                if currentIndex < steps.count - 1 {
                    let nextStep = steps[currentIndex + 1]
                    state.currentStep = nextStep
                    // Auto-expand Cuttle when reaching chatBasics or resize
                    if nextStep == .chatBasics || nextStep == .resize {
                        return .send(.delegate(.expandCuttle))
                    }
                    // Collapse when leaving chatBasics/resize
                    if steps[currentIndex] == .chatBasics || steps[currentIndex] == .resize {
                        return .send(.delegate(.collapseCuttle))
                    }
                } else {
                    return .send(.finish)
                }
                return .none

            case .previousStep:
                let steps = state.steps
                let currentIndex = state.currentStepIndex
                if currentIndex > 0 {
                    let prevStep = steps[currentIndex - 1]
                    // Collapse when leaving chatBasics/resize
                    if state.currentStep == .chatBasics || state.currentStep == .resize {
                        state.currentStep = prevStep
                        return .send(.delegate(.collapseCuttle))
                    }
                    state.currentStep = prevStep
                    // Expand when going back to chatBasics or resize
                    if prevStep == .chatBasics || prevStep == .resize {
                        return .send(.delegate(.expandCuttle))
                    }
                }
                return .none

            case .skipAll:
                state.isActive = false
                return .send(.delegate(.dismissed))

            case .finish:
                state.isActive = false
                return .send(.delegate(.completed))

            case .delegate:
                return .none
            }
        }
    }
}
