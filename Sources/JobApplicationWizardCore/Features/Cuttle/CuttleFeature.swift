import ComposableArchitecture
import Foundation

@Reducer
public struct CuttleFeature {
    private enum CancelID { case aiRequest }

    /// Maximum messages retained per context when saving chat history.
    private static let maxHistoryMessages = 100

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
        // Drag (with docking)
        case dragChanged(CGPoint)
        case dragEnded(CGPoint)
        // Drag (position only, no docking)
        case moveChanged(CGPoint)
        case moveEnded
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
        case aiResponseReceived(Result<(String, AITokenUsage, AgentActionBlock?), Error>)
        case clearChat
        case applySuggestion(String)
        // Lifecycle
        case restoreFromSettings(CuttleContext, [ChatMessage], [String: [ChatMessage]])
        case positionAtDropZone
        // Delegate (parent actions)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Job-context chat was updated; parent should persist to the job model.
            case jobChatUpdated(UUID, [ChatMessage])
            /// Cuttle docked on a job; parent should select it in the detail pane.
            case contextChanged(CuttleContext)
            /// Agent proposed actions to apply to a job.
            case agentActionsReceived([AgentAction], String)
        }
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
                // Clamp Y to stay below the title bar drag area
                state.position = CGPoint(x: location.x, y: max(location.y, Self.topInset))

                // Check drop zone proximity using cursor position.
                // Prefer more specific contexts (job > status > global) when zones overlap.
                let tolerance: CGFloat = 20
                state.pendingContext = nil
                var bestZone: DropZone? = nil
                for zone in state.dropZones {
                    let expanded = zone.frame.insetBy(dx: -tolerance, dy: -tolerance)
                    if expanded.contains(location) {
                        if let current = bestZone {
                            // Prefer more specific: .job > .status > .global
                            if specificity(zone.context) > specificity(current.context) {
                                bestZone = zone
                            }
                        } else {
                            bestZone = zone
                        }
                    }
                }
                state.pendingContext = bestZone?.context
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

            // MARK: - Move (no docking)

            case .moveChanged(let location):
                state.position = CGPoint(x: location.x, y: max(location.y, Self.topInset))
                return .none

            case .moveEnded:
                clampPosition(state: &state)
                return .none

            case .dropZonesUpdated(let zones):
                state.dropZones = zones
                // Track the docked card during scroll (when not dragging)
                if !state.isDragging {
                    snapToDropZone(state: &state, context: state.currentContext)
                }
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

                // Cancel any in-flight AI request to prevent cross-contamination
                let cancelEffect = Effect<Action>.cancel(id: CancelID.aiRequest)
                state.isLoading = false

                let saveEffect: Effect<Action>
                if !carry {
                    saveEffect = saveChatHistory(state: &state)
                } else {
                    saveEffect = .none
                }

                let newContext = pending
                state.currentContext = newContext
                state.acpSentSystemPrompt = false
                state.mood = .idle

                if !carry {
                    loadChatHistory(state: &state)
                }
                return .merge(cancelEffect, saveEffect, .send(.delegate(.contextChanged(newContext))))

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

                // Build system prompt using history BEFORE the just-appended user message,
                // since the user message is sent separately in the messages array.
                let priorHistory = Array(state.chatMessages.dropLast())
                let currentProvider = state.acpConnection.aiProvider
                let systemPrompt = CuttlePromptBuilder.buildPrompt(
                    context: state.currentContext,
                    jobs: state.jobs,
                    profile: state.userProfile,
                    chatHistory: priorHistory,
                    aiProvider: currentProvider
                )
                let messages = state.chatMessages

                // Determine if tools should be included (only for job context with Claude API)
                let isJobContext: Bool
                if case .job = state.currentContext { isJobContext = true } else { isJobContext = false }

                if state.acpConnection.aiProvider == .acpAgent && state.acpConnection.isConnected {
                    let contextPrefix = state.acpSentSystemPrompt ? "" : systemPrompt + "\n\n"
                    state.acpSentSystemPrompt = true
                    let fullMessage = contextPrefix + rawInput
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            let (text, usage) = try await acpClient.sendPrompt(fullMessage, messages)
                            // ACP fallback: extract actions from text markers
                            let actionBlock = TextActionExtractor.extract(from: text)
                            let cleanText = actionBlock != nil ? TextActionExtractor.stripActions(from: text) : text
                            return (cleanText, usage, actionBlock)
                        }))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                } else {
                    let key = state.apiKey
                    let includeTools = isJobContext
                    return .run { send in
                        await send(.aiResponseReceived(Result {
                            try await claudeClient.chat(key, systemPrompt, messages, includeTools)
                        }))
                    }
                    .cancellable(id: CancelID.aiRequest, cancelInFlight: true)
                }

            case .aiResponseReceived(.success(let (text, usage, actionBlock))):
                state.isLoading = false
                state.mood = .idle
                if !text.isEmpty {
                    state.chatMessages.append(ChatMessage(role: .assistant, content: text))
                }
                state.tokenUsage = AITokenUsage(
                    inputTokens: state.tokenUsage.inputTokens + usage.inputTokens,
                    outputTokens: state.tokenUsage.outputTokens + usage.outputTokens
                )
                let saveEffect = saveChatHistory(state: &state)

                // If actions were received and we're in a job context, delegate to parent
                if let block = actionBlock, !block.actions.isEmpty,
                   case .job = state.currentContext {
                    return .merge(
                        saveEffect,
                        .send(.delegate(.agentActionsReceived(block.actions, block.summary)))
                    )
                }
                return saveEffect

            case .aiResponseReceived(.failure(let error)):
                state.isLoading = false
                state.mood = .idle
                state.error = "\(type(of: error)): \(error.localizedDescription)"
                // Save the dangling user message so it isn't lost on context switch
                return saveChatHistory(state: &state)

            case .clearChat:
                state.chatMessages = []
                state.chatInput = ""
                state.error = nil
                state.tokenUsage = .zero
                state.acpSentSystemPrompt = false
                return saveChatHistory(state: &state)

            case .applySuggestion(let prompt):
                state.chatInput = prompt
                return .send(.sendMessage(prompt))

            // MARK: - Lifecycle

            case .restoreFromSettings(let context, let globalHistory, let statusHistories):
                state.currentContext = context
                state.globalChatHistory = globalHistory
                state.statusChatHistories = statusHistories
                loadChatHistory(state: &state)
                return .none

            case .positionAtDropZone:
                snapToDropZone(state: &state, context: state.currentContext)
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Helpers

    /// Returns a specificity score for drop zone priority (higher = more specific).
    private func specificity(_ context: CuttleContext) -> Int {
        switch context {
        case .global: return 0
        case .status: return 1
        case .job: return 2
        }
    }

    private func switchContextSilently(state: inout State, to context: CuttleContext) -> Effect<Action> {
        // Cancel any in-flight AI request to prevent cross-contamination
        let cancelEffect = Effect<Action>.cancel(id: CancelID.aiRequest)
        state.isLoading = false

        // Save current history before switching
        let saveEffect = saveChatHistory(state: &state)

        state.pendingContext = nil
        state.currentContext = context
        state.acpSentSystemPrompt = false
        state.mood = .idle

        // Load history for new context
        loadChatHistory(state: &state)

        // Snap to zone
        snapToDropZone(state: &state, context: context)
        return .merge(cancelEffect, saveEffect, .send(.delegate(.contextChanged(context))))
    }

    private func snapToDropZone(state: inout State, context: CuttleContext) {
        if let zone = state.dropZones.first(where: { $0.context == context }) {
            state.position = CGPoint(x: zone.frame.midX, y: zone.frame.midY)
        }
    }

    /// Minimum Y to keep Cuttle below the title bar / toolbar drag area.
    private static let topInset: CGFloat = 52

    private func clampPosition(state: inout State) {
        let margin: CGFloat = 24
        if state.windowSize.width > 0 {
            state.position.x = max(margin, min(state.position.x, state.windowSize.width - margin))
        }
        if state.windowSize.height > 0 {
            state.position.y = max(Self.topInset, min(state.position.y, state.windowSize.height - margin))
        }
    }

    /// Saves chat messages to the appropriate history store, with pruning.
    /// Returns a delegate effect for job-context so AppFeature can persist to the job model.
    private func saveChatHistory(state: inout State) -> Effect<Action> {
        let pruned = Array(state.chatMessages.suffix(Self.maxHistoryMessages))

        switch state.currentContext {
        case .global:
            state.globalChatHistory = pruned
            return .none
        case .status(let status):
            state.statusChatHistories[status.rawValue] = pruned
            return .none
        case .job(let id):
            // Notify AppFeature to write chat back to the job model
            return .send(.delegate(.jobChatUpdated(id, pruned)))
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
