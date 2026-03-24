import ComposableArchitecture
import Foundation

@Reducer
public struct CuttleOnboardingFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentStep: OnboardingStep = .discoverAgent
        public var isActive: Bool = false
        public var aiReady: Bool = false

        // Agent discovery state
        public var availableAgents: [ACPAgentEntry] = []
        public var isLoadingAgents: Bool = false
        public var agentSearchText: String = ""
        public var selectedAgentId: String? = nil
        public var registryError: String? = nil
        public var isConnecting: Bool = false
        public var connectionError: String? = nil
        public var isConnected: Bool = false
        public var connectedAgentName: String? = nil

        public var steps: [OnboardingStep] {
            OnboardingStep.allCases.filter { step in
                if step == .discoverAgent || step == .connectAgent {
                    return !aiReady
                }
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

        public var filteredAgents: [ACPAgentEntry] {
            if agentSearchText.isEmpty { return availableAgents }
            let query = agentSearchText.lowercased()
            return availableAgents.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        public var selectedAgent: ACPAgentEntry? {
            availableAgents.first { $0.id == selectedAgentId }
        }

        public init() {}
    }

    public enum OnboardingStep: String, CaseIterable, Equatable {
        case discoverAgent
        case connectAgent
        case meetCuttle
        case expandCollapse
        case chatBasics
        case dragToDock
        case carryOrFresh
        case resize

        public var title: String {
            switch self {
            case .discoverAgent: return "Find Your AI Agent"
            case .connectAgent: return "Connect Agent"
            case .meetCuttle: return "Meet Cuttle"
            case .expandCollapse: return "Expand / Collapse"
            case .chatBasics: return "Chat Basics"
            case .dragToDock: return "Drag to Dock"
            case .carryOrFresh: return "Carry or Fresh"
            case .resize: return "Resize"
            }
        }

        public var body: String {
            switch self {
            case .discoverAgent:
                return "Choose an ACP agent to power Cuttle. Browse the registry below, then select one to continue."
            case .connectAgent:
                return "Connect to your chosen agent. The app will launch and initialize it automatically."
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
            }
        }

        public var spotlightTarget: SpotlightTarget {
            switch self {
            case .discoverAgent: return .none
            case .connectAgent: return .none
            case .meetCuttle: return .blob
            case .expandCollapse: return .blob
            case .chatBasics: return .chatWindow
            case .dragToDock: return .dockTargets
            case .carryOrFresh: return .none
            case .resize: return .chatWindow
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
        // Agent discovery
        case fetchRegistry
        case registryLoaded(Result<[ACPAgentEntry], Error>)
        case searchTextChanged(String)
        case selectAgent(String)
        case connectToAgent
        case connectionResult(Result<String, Error>)
        case retryConnection
        case skipAgentSetup
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case completed
            case dismissed
            case expandCuttle
            case collapseCuttle
            case agentConnected(agentId: String, agentName: String)
        }
    }

    @Dependency(\.acpRegistryClient) var acpRegistry
    @Dependency(\.acpClient) var acpClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                state.isActive = true
                state.currentStep = state.steps.first ?? .meetCuttle
                if state.currentStep == .discoverAgent {
                    return .send(.fetchRegistry)
                }
                return .none

            case .fetchRegistry:
                state.isLoadingAgents = true
                state.registryError = nil
                return .run { send in
                    do {
                        let agents = try await acpRegistry.fetchAgents()
                        await send(.registryLoaded(.success(agents)))
                    } catch {
                        await send(.registryLoaded(.failure(error)))
                    }
                }

            case .registryLoaded(.success(let agents)):
                state.isLoadingAgents = false
                state.availableAgents = agents
                return .none

            case .registryLoaded(.failure(let error)):
                state.isLoadingAgents = false
                state.registryError = error.localizedDescription
                return .none

            case .searchTextChanged(let text):
                state.agentSearchText = text
                return .none

            case .selectAgent(let agentId):
                state.selectedAgentId = agentId
                return .none

            case .connectToAgent:
                guard let agent = state.selectedAgent else { return .none }
                state.isConnecting = true
                state.connectionError = nil
                return .run { send in
                    do {
                        let name = try await acpClient.connect(agent)
                        await send(.connectionResult(.success(name)))
                    } catch {
                        await send(.connectionResult(.failure(error)))
                    }
                }

            case .connectionResult(.success(let name)):
                state.isConnecting = false
                state.isConnected = true
                state.connectedAgentName = name
                state.aiReady = true
                let agentId = state.selectedAgentId ?? ""
                return .send(.delegate(.agentConnected(agentId: agentId, agentName: name)))

            case .connectionResult(.failure(let error)):
                state.isConnecting = false
                state.connectionError = error.localizedDescription
                return .none

            case .retryConnection:
                return .send(.connectToAgent)

            case .skipAgentSetup:
                state.currentStep = .meetCuttle
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
