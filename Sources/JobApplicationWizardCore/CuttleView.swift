import SwiftUI
import ComposableArchitecture

// MARK: - CuttleView

/// A free-floating, draggable cuttlefish blob that provides context-aware AI chat.
public struct CuttleView: View {
    @Bindable var store: StoreOf<CuttleFeature>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings

    @State private var thinkingAmplitude: Double = 0.01
    @State private var showThinking: Bool = false
    @State private var chatSize: CGSize = CGSize(width: 380, height: 480)
    @GestureState private var resizeStart: CGSize? = nil

    private static let collapsedSize: CGFloat = 48
    private static let expandedSize: CGFloat = 56
    private static let minChatWidth: CGFloat = 300
    private static let maxChatWidth: CGFloat = 600
    private static let minChatHeight: CGFloat = 320
    private static let maxChatHeight: CGFloat = 800

    public init(store: StoreOf<CuttleFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            // Click-outside-to-collapse overlay.
            // Uses a clear background that only captures mouse clicks,
            // allowing keyboard shortcuts and accessibility to pass through.
            if store.isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.send(.collapse)
                    }
                    .accessibilityHidden(true)
            }

            // Main Cuttle content
            if store.isExpanded {
                expandedView
                    .position(expandedPosition)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // The blob (visual only; drag is handled by the drag layer below)
            blobView
                .position(store.isExpanded ? blobExpandedPosition : store.position)
                .allowsHitTesting(false)

            // Invisible drag surface pinned at the blob's visual position.
            // Because this uses a fixed-size frame positioned in the stable
            // ZStack, the "cuttle-window" coordinate space stays correct
            // throughout the entire drag.
            Color.clear
                .frame(width: Self.collapsedSize + 16, height: Self.collapsedSize + 16)
                .contentShape(Circle())
                .position(store.isExpanded ? blobExpandedPosition : store.position)
                .onTapGesture(count: 2) {
                    store.send(.toggleExpanded)
                }
                .gesture(
                    DragGesture(coordinateSpace: .named("cuttle-window"))
                        .onChanged { value in
                            var loc = value.location
                            // When expanded, the drag surface is at the blob position
                            // above the chat. Subtract the blob height so the position
                            // (which drives the chat) tracks the cursor, not the blob.
                            if store.isExpanded {
                                loc.y += Self.collapsedSize / 2 + 4
                            }
                            store.send(.dragChanged(loc))
                        }
                        .onEnded { value in
                            var loc = value.location
                            if store.isExpanded {
                                loc.y += Self.collapsedSize / 2 + 4
                            }
                            store.send(.dragEnded(loc))
                        }
                )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: store.position)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.isExpanded)
        .alert("Switch Context?", isPresented: Binding(
            get: { store.showContextTransitionAlert },
            set: { if !$0 { store.send(.cancelContextTransition) } }
        )) {
            Button("Carry Conversation") { store.send(.contextTransitionConfirmed(carry: true)) }
            Button("Start Fresh") { store.send(.contextTransitionConfirmed(carry: false)) }
            Button("Cancel", role: .cancel) { store.send(.cancelContextTransition) }
        } message: {
            Text("You have an active conversation. Would you like to carry it to the new context or start fresh?")
        }
        .onChange(of: store.isLoading) { _, loading in
            if loading {
                thinkingAmplitude = 0.01
                showThinking = true
                withAnimation(.easeIn(duration: 2.0)) {
                    thinkingAmplitude = 0.08
                }
            } else {
                showThinking = false
                thinkingAmplitude = 0.01
            }
        }
        .onKeyPress(.escape) {
            if store.isExpanded {
                store.send(.collapse)
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Blob View (collapsed bubble)

    private var blobView: some View {
        VStack(spacing: 4) {
            JitterCircle(
                size: store.isDragging ? Self.expandedSize : Self.collapsedSize,
                mood: store.mood
            )

            // Context label
            Text(store.currentContext.displayLabel(jobs: store.jobs))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .lineLimit(1)
                .frame(maxWidth: 120)
        }
    }

    // MARK: - Blob Position When Expanded

    /// Places the blob just above the top-center of the chat container.
    private var blobExpandedPosition: CGPoint {
        let chatPos = expandedPosition
        let halfH = chatSize.height / 2
        return CGPoint(
            x: chatPos.x,
            y: chatPos.y - halfH - Self.collapsedSize / 2 - 4
        )
    }

    // MARK: - Expanded Position (anchored to blob)

    private var expandedPosition: CGPoint {
        let blobPos = store.position
        let windowSize = store.windowSize
        let w = chatSize.width
        let h = chatSize.height

        // Space needed above the chat for the blob + label + gap
        let blobOverhead = Self.collapsedSize / 2 + 4
        // Minimum Y for the chat center so the blob stays below the title bar (52pt)
        let topInset: CGFloat = 52
        let minChatCenterY = topInset + blobOverhead + h / 2

        // Default: chat container below and to the right of the blob
        var x = blobPos.x + w / 2 - Self.collapsedSize / 2
        var y = blobPos.y + h / 2 + Self.collapsedSize

        // Clamp to window bounds
        let margin: CGFloat = 8
        if x + w / 2 > windowSize.width - margin {
            x = windowSize.width - margin - w / 2
        }
        if x - w / 2 < margin {
            x = margin + w / 2
        }
        if y + h / 2 > windowSize.height - margin {
            // Show above the blob instead
            y = blobPos.y - h / 2 - Self.collapsedSize
        }
        // Ensure the blob above the chat doesn't go into the title bar
        if y < minChatCenterY {
            y = minChatCenterY
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Expanded Chat View

    /// Returns the thread store for the current context.
    private var currentThreadStore: CuttleThreadStore {
        switch store.currentContext {
        case .global:
            return store.globalThreadStore
        case .status(let status):
            return store.statusThreadStores[status.rawValue] ?? CuttleThreadStore()
        case .job(let id):
            return store.jobs.first(where: { $0.id == id })?.chatThreadStore ?? CuttleThreadStore()
        }
    }

    /// Threads for the active context only, newest first by creation time.
    private var currentThreads: [CuttleThread] {
        let threadStore = currentThreadStore
        var threads = threadStore.threads
        if let activeIdx = threadStore.activeThreadIndex, !store.chatMessages.isEmpty {
            threads[activeIdx].messages = store.chatMessages
        }
        return threads.sorted { $0.createdAt > $1.createdAt }
    }

    private var expandedView: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                // Header with provider info
                headerBar

                Divider()

                if store.acpConnection.isConnecting {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView().controlSize(.regular)
                    Text("Connecting to AI agent...")
                        .font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if !aiReady {
                notReadyView
            } else {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if store.chatMessages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(store.chatMessages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                                if showThinking {
                                    HStack {
                                        JitterCircle(size: 40, amplitudeFrac: thinkingAmplitude)
                                            .frame(width: 40, height: 40)
                                        Spacer()
                                    }
                                    .id("thinking")
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(16)
                    }
                    .onChange(of: store.chatMessages.count) { _, _ in
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                    }
                    .onChange(of: store.isLoading) { _, loading in
                        if loading {
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                    }
                }

                Divider()

                // Input bar
                ChatInputBar(
                    input: $store.chatInput,
                    isLoading: store.isLoading,
                    isReady: aiReady,
                    error: store.error,
                    onSend: { store.send(.sendMessage(store.chatInput)) },
                    onClear: { store.send(.clearChat) },
                    hasMessages: !store.chatMessages.isEmpty
                )
            }
        }
            .contentShape(Rectangle())
            .onTapGesture {
                if store.isDrawerOpen {
                    store.send(.toggleDrawer)
                }
            }

            // Thread drawer overlay
            if store.isDrawerOpen {
                threadDrawer
                    .onTapGesture { } // absorb taps so they don't close the drawer
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isDrawerOpen)
        .frame(width: chatSize.width, height: chatSize.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.5))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($resizeStart) { _, state, _ in
                        if state == nil { state = chatSize }
                    }
                    .onChanged { value in
                        guard let start = resizeStart else { return }
                        chatSize = CGSize(
                            width: min(Self.maxChatWidth, max(Self.minChatWidth, start.width + value.translation.width)),
                            height: min(Self.maxChatHeight, max(Self.minChatHeight, start.height + value.translation.height))
                        )
                    }
            )
            .padding(6)
    }

    // MARK: - Thread Drawer

    private var threadDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Threads")
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Button {
                    store.send(.createThread)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Thread")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(currentThreads) { thread in
                        threadRow(thread: thread)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(4)
    }

    private func threadRow(thread: CuttleThread) -> some View {
        let activeId = currentThreadStore.activeThreadId ?? currentThreadStore.threads.first?.id
        let isActive = thread.id == activeId
        return Button {
            store.send(.selectThread(thread.id))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .white : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.displayName)
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(isActive ? .white : .primary)
                        .lineLimit(1)

                    if let lastMessage = thread.messages.last {
                        Text(lastMessage.content)
                            .font(.caption2)
                            .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !thread.messages.isEmpty {
                    Text("\(thread.messages.count)")
                        .font(.caption2).fontWeight(.medium)
                        .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.send(.deleteThread(thread.id))
            } label: {
                Label("Delete Thread", systemImage: "trash")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 6) {
            Button {
                store.send(.toggleDrawer)
            } label: {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Thread drawer")

            Text(store.currentContext.displayLabel(jobs: store.jobs))
                .font(.caption).fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            if store.acpConnection.aiProvider == .acpAgent, let name = store.acpConnection.connectedAgentName {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text(name)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1)
            } else if store.acpConnection.aiProvider == .claudeAPI && store.tokenUsage.totalTokens > 0 {
                Text("\(store.tokenUsage.totalTokens.formatted()) tok")
                    .font(.caption2).foregroundColor(.secondary)
                Text(String(format: "~$%.4f", store.tokenUsage.estimatedCost))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(coordinateSpace: .named("cuttle-window"))
                .onChanged { value in
                    store.send(.moveChanged(value.location))
                }
                .onEnded { _ in
                    store.send(.moveEnded)
                }
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if store.acpConnection.aiProvider == .acpAgent, let name = store.acpConnection.connectedAgentName {
                Text("Connected to \(name)")
                    .font(.subheadline).fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("AI Assistant")
                    .font(.subheadline).fontWeight(.medium)
            }

            Text(contextHelpText)
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            FlowLayout(spacing: 8) {
                ForEach(suggestionChips, id: \.self) { chip in
                    SuggestionChip(chip) {
                        store.send(.applySuggestion(chip))
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private var contextHelpText: String {
        switch store.currentContext {
        case .global:
            return "Ask about your overall job search, compare prospects, or get strategy advice."
        case .status:
            return "Ask about jobs in this phase, spot patterns, or get targeted advice."
        case .job:
            return "Ask anything about this application, or try a suggestion below."
        }
    }

    private var suggestionChips: [String] {
        switch store.currentContext {
        case .global:
            return [
                "Summarize my job search",
                "Which roles should I prioritize?",
                "Compare my top prospects",
            ]
        case .status(let status):
            switch status {
            case .interview:
                return ["Prep me for upcoming interviews", "Compare interview timelines"]
            case .rejected:
                return ["What patterns do you see?", "How can I improve?"]
            case .offer:
                return ["Help me negotiate", "Compare these offers"]
            case .wishlist:
                return ["Which should I apply to first?", "Evaluate these prospects"]
            case .applied:
                return ["Draft follow-up emails", "What should I prepare?"]
            case .phoneScreen:
                return ["Prep me for phone screens", "What questions to expect?"]
            case .withdrawn:
                return ["What can I learn?", "Refine my search criteria"]
            }
        case .job:
            return [
                "Analyze my fit",
                "Tailor my resume",
                "Draft a cover letter",
                "Prep me for interviews",
            ]
        }
    }

    // MARK: - Not Ready View

    private var notReadyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: store.acpConnection.aiProvider == .claudeAPI ? "key.fill" : "cpu")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            if store.acpConnection.aiProvider == .acpAgent {
                Text("Connect an AI Agent")
                    .font(.headline)
                Text("Open Settings to connect an ACP-compatible agent.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            } else {
                Text("Add Your API Key")
                    .font(.headline)
                Text("Enter your Claude API key in Settings.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button {
                NotificationCenter.default.post(name: .selectSettingsTab, object: SettingsTab.aiProvider)
                openSettings()
            } label: {
                Label("Set Up AI Provider", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var aiReady: Bool {
        store.acpConnection.aiProvider == .claudeAPI ? !store.apiKey.isEmpty : store.acpConnection.isConnected
    }
}
