import ComposableArchitecture
import Foundation

@Reducer
public struct CuttleFeature {
    private enum CancelID { case aiRequest }

    @ObservableState
    public struct State: Equatable {
        // Context
        public var currentContext: CuttleContext = .global
        /// Non-nil only while actively dragging over a drop zone; drives the glow overlay.
        public var pendingContext: CuttleContext? = nil
        /// Saved pending context for the carry/fresh alert (persists after drag ends).
        public var alertPendingContext: CuttleContext? = nil
        public var showContextTransitionAlert: Bool = false

        // Position & drag
        public var position: CGPoint = CGPoint(x: 60, y: 120)
        public var dragOffset: CGSize = .zero
        public var isDragging: Bool = false

        // Expansion
        public var isExpanded: Bool = false

        // Chat state
        public var chatInput: String = ""
        public var chatMessages: [ChatMessage] = []
        public var isLoading: Bool = false
        public var error: String? = nil
        public var acpSentSystemPrompt: Bool = false
        public var tokenUsage: AITokenUsage = .zero

        // Mood
        public var mood: CuttleMood = .idle

        // Drop zones reported by views
        public var dropZones: [DropZone] = []

        // Read-only references synced from AppFeature
        public var apiKey: String = ""
        public var userProfile: UserProfile = UserProfile()
        public var jobs: [JobApplication] = []

        // Persisted chat histories (global and per-status)
        public var globalChatHistory: [ChatMessage] = []
        public var statusChatHistories: [String: [ChatMessage]] = [:]

        // ACP connection (shared)
        @SharedReader(.inMemory("acpConnection")) public var acpConnection = ACPConnectionState()

        // Window size for clamping
        public var windowSize: CGSize = .zero

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        // Drag
        case dragChanged(CGPoint)
        case dragEnded(CGPoint)
        case dropZonesUpdated([DropZone])
        case windowSizeChanged(CGSize)
        // Expand/collapse
        case toggleExpanded
        case collapse
        // Context transition
        case contextTransitionConfirmed(carry: Bool)
        case cancelContextTransition
        case switchContext(CuttleContext)
        // Chat
        case sendMessage(String)
        case aiResponseReceived(Result<(String, AITokenUsage), Error>)
        case clearChat
        case applySuggestion(String)
        // Lifecycle
        case restoreFromSettings(CuttleContext, [ChatMessage], [String: [ChatMessage]])
        case positionAtDropZone
    }

    @Dependency(\.claudeClient) var claudeClient
    @Dependency(\.acpClient) var acpClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // MARK: - Drag

            case .dragChanged(let location):
                state.isDragging = true
                state.mood = .listening
                state.position = location

                // Check drop zone proximity using cursor position
                let tolerance: CGFloat = 20
                state.pendingContext = nil
                for zone in state.dropZones {
                    let expanded = zone.frame.insetBy(dx: -tolerance, dy: -tolerance)
                    if expanded.contains(location) {
                        state.pendingContext = zone.context
                        break
                    }
                }
                return .none

            case .dragEnded:
                state.isDragging = false
                let pending = state.pendingContext
                let wasExpanded = state.isExpanded
                state.pendingContext = nil  // always clear; glow is drag-only

                if let pending {
                    // Collapse chat when re-docking via drag
                    if wasExpanded { state.isExpanded = false }

                    if pending != state.currentContext && !state.chatMessages.isEmpty {
                        // Show transition alert
                        state.alertPendingContext = pending
                        state.showContextTransitionAlert = true
                        state.mood = .transitioning
                        snapToDropZone(state: &state, context: pending)
                    } else {
                        return switchContextSilently(state: &state, to: pending)
                    }
                } else {
                    state.mood = .idle
                    if !wasExpanded {
                        clampPosition(state: &state)
                    }
                }
                return .none

            case .dropZonesUpdated(let zones):
                state.dropZones = zones
                return .none

            case .windowSizeChanged(let size):
                state.windowSize = size
                clampPosition(state: &state)
                return .none

            // MARK: - Expand / Collapse

            case .toggleExpanded:
                state.isExpanded.toggle()
                return .none

            case .collapse:
                state.isExpanded = false
                return .none

            // MARK: - Context Transition

            case .contextTransitionConfirmed(let carry):
                guard let pending = state.alertPendingContext else { return .none }
                state.showContextTransitionAlert = false
                state.alertPendingContext = nil

                if !carry {
                    // Save current chat before switching
                    saveChatHistory(state: &state)
                }

                let newContext = pending
                state.currentContext = newContext
                state.acpSentSystemPrompt = false
                state.mood = .idle

                if carry {
                    // Keep current messages
                } else {
                    // Load history for new context
                    loadChatHistory(state: &state)
                }
                return .none

            case .cancelContextTransition:
                state.showContextTransitionAlert = false
                state.alertPendingContext = nil
                state.mood = .idle
                // Snap back to current context's zone
                snapToDropZone(state: &state, context: state.currentContext)
                return .none

            case .switchContext(let context):
                return switchContextSilently(state: &state, to: context)

            // MARK: - Chat

            case .sendMessage(let text):
                let rawInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawInput.isEmpty else { return .none }

                state.chatMessages.append(ChatMessage(role: .user, content: rawInput))
                state.chatInput = ""
                state.isLoading = true
                state.error = nil
                state.mood = .thinking

                let systemPrompt = CuttlePromptBuilder.buildPrompt(
                    context: state.currentContext,
                    jobs: state.jobs,
                    profile: state.userProfile,
                    chatHistory: state.chatMessages
                )
                let messages = state.chatMessages

                if state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected {
                    let contextPrefix = state.acpSentSystemPrompt ? "" : systemPrompt + "\n\n"
                    state.acpSentSystemPrompt = true
                    let fullMessage = contextPrefix + rawInput
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            try await acpClient.sendPrompt(fullMessage, messages)
                        }))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                } else {
                    let key = state.apiKey
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            try await claudeClient.chat(key, systemPrompt, messages)
                        } as Result<(String, AITokenUsage), Error>))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                }

            case .aiResponseReceived(.success(let (text, usage))):
                state.isLoading = false
                state.mood = .idle
                state.chatMessages.append(ChatMessage(role: .assistant, content: text))
                state.tokenUsage = AITokenUsage(
                    inputTokens: state.tokenUsage.inputTokens + usage.inputTokens,
                    outputTokens: state.tokenUsage.outputTokens + usage.outputTokens
                )
                // Persist chat history for the current context
                saveChatHistory(state: &state)
                return .none

            case .aiResponseReceived(.failure(let error)):
                state.isLoading = false
                state.mood = .idle
                state.error = "\(type(of: error)): \(error.localizedDescription)"
                return .none

            case .clearChat:
                state.chatMessages = []
                state.chatInput = ""
                state.error = nil
                state.tokenUsage = .zero
                state.acpSentSystemPrompt = false
                saveChatHistory(state: &state)
                return .none

            case .applySuggestion(let prompt):
                state.chatInput = prompt
                return .send(.sendMessage(prompt))

            // MARK: - Lifecycle

            case .restoreFromSettings(let context, let globalHistory, let statusHistories):
                state.currentContext = context
                state.globalChatHistory = globalHistory
                state.statusChatHistories = statusHistories
                // Load the correct history for the restored context
                loadChatHistory(state: &state)
                return .none

            case .positionAtDropZone:
                snapToDropZone(state: &state, context: state.currentContext)
                return .none
            }
        }
    }

    // MARK: - Helpers

    private func switchContextSilently(state: inout State, to context: CuttleContext) -> Effect<Action> {
        // Save current history before switching
        saveChatHistory(state: &state)

        state.pendingContext = nil
        state.currentContext = context
        state.acpSentSystemPrompt = false
        state.mood = .idle

        // Load history for new context
        loadChatHistory(state: &state)

        // Snap to zone
        snapToDropZone(state: &state, context: context)
        return .none
    }

    private func snapToDropZone(state: inout State, context: CuttleContext) {
        if let zone = state.dropZones.first(where: { $0.context == context }) {
            state.position = CGPoint(x: zone.frame.midX, y: zone.frame.midY)
        }
    }

    private func clampPosition(state: inout State) {
        let margin: CGFloat = 24
        if state.windowSize.width > 0 {
            state.position.x = max(margin, min(state.position.x, state.windowSize.width - margin))
        }
        if state.windowSize.height > 0 {
            state.position.y = max(margin, min(state.position.y, state.windowSize.height - margin))
        }
    }

    private func saveChatHistory(state: inout State) {
        switch state.currentContext {
        case .global:
            state.globalChatHistory = state.chatMessages
        case .status(let status):
            state.statusChatHistories[status.rawValue] = state.chatMessages
        case .job(let id):
            // Job chat is stored on the job itself; handled by AppFeature sync
            if var job = state.jobs.first(where: { $0.id == id }) {
                job.chatHistory = state.chatMessages
                // Note: actual persistence goes through AppFeature delegate
            }
            break
        }
    }

    private func loadChatHistory(state: inout State) {
        switch state.currentContext {
        case .global:
            state.chatMessages = state.globalChatHistory
        case .status(let status):
            state.chatMessages = state.statusChatHistories[status.rawValue] ?? []
        case .job(let id):
            if let job = state.jobs.first(where: { $0.id == id }) {
                state.chatMessages = job.chatHistory
            } else {
                state.chatMessages = []
            }
        }
        state.tokenUsage = .zero
        state.error = nil
    }
}
