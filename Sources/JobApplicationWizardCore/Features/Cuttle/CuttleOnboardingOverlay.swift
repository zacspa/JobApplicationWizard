import SwiftUI
import ComposableArchitecture

public struct CuttleOnboardingOverlay: View {
    let store: StoreOf<CuttleOnboardingFeature>
    let cuttlePosition: CGPoint
    let cuttleIsExpanded: Bool
    let chatSize: CGSize
    let isResizing: Bool
    let windowSize: CGSize
    let dropZones: [DropZone]
    let safeAreaTopInset: CGFloat

    public init(
        store: StoreOf<CuttleOnboardingFeature>,
        cuttlePosition: CGPoint,
        cuttleIsExpanded: Bool,
        chatSize: CGSize = CGSize(width: 380, height: 480),
        isResizing: Bool = false,
        windowSize: CGSize,
        dropZones: [DropZone],
        safeAreaTopInset: CGFloat = 0
    ) {
        self.store = store
        self.cuttlePosition = cuttlePosition
        self.cuttleIsExpanded = cuttleIsExpanded
        self.chatSize = chatSize
        self.isResizing = isResizing
        self.windowSize = windowSize
        self.dropZones = dropZones
        self.safeAreaTopInset = safeAreaTopInset
    }

    public var body: some View {
        ZStack {
            // Dimming layer with spotlight cutout
            dimmingLayer
                .allowsHitTesting(false)

            // Step-specific content
            switch store.currentStep {
            case .discoverAgent:
                agentDiscoveryCard
            case .connectAgent:
                connectAgentCard
            default:
                tooltipCard
            }
        }
        .opacity(isResizing ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: store.currentStep)
        .animation(.easeInOut(duration: 0.2), value: isResizing)
    }

    // MARK: - Dimming Layer

    @ViewBuilder
    private var dimmingLayer: some View {
        let rects = spotlightFrames(for: store.currentStep)
        Color.black.opacity(0.4)
            .mask {
                Rectangle()
                    .overlay {
                        ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                            if rect != .zero {
                                let expanded = rect.insetBy(dx: -12, dy: -12)
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .frame(width: expanded.width, height: expanded.height)
                                    .position(x: expanded.midX, y: expanded.midY)
                                    .blendMode(.destinationOut)
                            }
                        }
                    }
                    .compositingGroup()
            }
    }

    // MARK: - Agent Discovery Card

    @ViewBuilder
    private var agentDiscoveryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Find Your AI Agent")
                .font(DS.Typography.heading2)

            Text("Choose an ACP agent to power Cuttle. Browse the registry below, then select one to continue.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Search field
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DS.Color.textSecondary)
                TextField("Search agents...", text: Binding(
                    get: { store.agentSearchText },
                    set: { store.send(.searchTextChanged($0)) }
                ))
                .textFieldStyle(.plain)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Color.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .stroke(DS.Color.border, lineWidth: 1)
            )

            // Agent list
            if store.isLoadingAgents {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading agents...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.textSecondary)
                    Spacer()
                }
                .frame(height: 240)
            } else if let error = store.registryError {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(DS.Color.warning)
                    Text(error)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Color.error)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        store.send(.fetchRegistry)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xxs) {
                        ForEach(store.filteredAgents) { agent in
                            agentRow(agent)
                        }
                    }
                }
                .frame(height: 240)
            }

            // Install instructions when an agent is selected
            if let agent = store.selectedAgent {
                installInstructions(for: agent)
            }

            // Navigation
            HStack {
                stepDots
                Spacer()
                Button("Skip") {
                    store.send(.skipAgentSetup)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Next") {
                    store.send(.nextStep)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.selectedAgentId == nil)
                .keyboardShortcut(.return)
            }

            HStack {
                Spacer()
                Button("Skip Tour") {
                    store.send(.skipAll)
                }
                .buttonStyle(.plain)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .position(x: windowSize.width / 2, y: windowSize.height / 2)
    }

    @ViewBuilder
    private func agentRow(_ agent: ACPAgentEntry) -> some View {
        let isSelected = store.selectedAgentId == agent.id
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(agent.name)
                        .font(DS.Typography.bodyMedium)
                    Text("v\(agent.version)")
                        .font(DS.Typography.caption2)
                        .padding(.horizontal, DS.Spacing.xxs)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(DS.Color.Opacity.wash))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
                }
                Text(agent.description)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Color.textSecondary)
                    .lineLimit(2)
                HStack(spacing: DS.Spacing.xxs) {
                    if agent.distribution.npx != nil {
                        distributionBadge("npx")
                    }
                    if agent.distribution.uvx != nil {
                        distributionBadge("uvx")
                    }
                    if agent.distribution.binary != nil {
                        distributionBadge("binary")
                    }
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(DS.Spacing.sm)
        .background(isSelected ? Color.accentColor.opacity(DS.Color.Opacity.tint) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.selectAgent(agent.id))
        }
    }

    @ViewBuilder
    private func distributionBadge(_ label: String) -> some View {
        Text(label)
            .font(DS.Typography.micro)
            .padding(.horizontal, DS.Spacing.xxs)
            .padding(.vertical, 1)
            .background(DS.Color.info.opacity(DS.Color.Opacity.wash))
            .foregroundColor(DS.Color.info)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
    }

    @ViewBuilder
    private func installInstructions(for agent: ACPAgentEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Prerequisites
            Text("Prerequisites:")
                .font(DS.Typography.captionSemibold)

            let prereq = prerequisite(for: agent)
            Text(prereq)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let website = agent.website, !website.isEmpty {
                Link("Learn more at \(websiteDisplayName(website))", destination: URL(string: website)!)
                    .font(DS.Typography.caption)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
    }

    private func prerequisite(for agent: ACPAgentEntry) -> String {
        // Hardcoded prerequisites for well-known agents
        switch agent.id {
        case "claude-acp":
            return "Install Claude Code (npm i -g @anthropic-ai/claude-code) or Claude Desktop, and sign in with your Anthropic account."
        case "github-copilot-cli":
            return "Install GitHub CLI (brew install gh) with the Copilot extension (gh extension install github/gh-copilot), and sign in with a GitHub Copilot subscription."
        case "cursor":
            return "Install Cursor IDE from cursor.com and sign in."
        case "codex-acp":
            return "Install OpenAI Codex CLI (npm i -g @openai/codex) and set your OpenAI API key."
        case "gemini":
            return "Sign in with your Google account (gcloud auth login) or set a Google AI API key."
        case "goose":
            return "Standalone agent; configure your preferred LLM provider API key on first run."
        case "amp-acp":
            return "Install Amp CLI and sign in with your Amp account."
        default:
            return defaultPrerequisite(for: agent)
        }
    }

    private func defaultPrerequisite(for agent: ACPAgentEntry) -> String {
        if let website = agent.website, !website.isEmpty {
            return "Check \(websiteDisplayName(website)) for setup instructions."
        }
        // Fall back to runtime requirement
        if agent.distribution.npx != nil {
            return "Requires Node.js installed on your system."
        } else if agent.distribution.uvx != nil {
            return "Requires Python with uv installed on your system."
        } else if agent.distribution.binary != nil {
            return "Standalone binary; no additional runtime needed."
        }
        return "See the agent's documentation for setup instructions."
    }

    private func websiteDisplayName(_ url: String) -> String {
        var host = url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if host.hasSuffix("/") { host = String(host.dropLast()) }
        // Trim long paths
        if let slash = host.firstIndex(of: "/") {
            let domain = String(host[host.startIndex..<slash])
            return domain
        }
        return host
    }

    // MARK: - Connect Agent Card

    @ViewBuilder
    private var connectAgentCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            let agentName = store.selectedAgent?.name ?? "Agent"

            Text("Connect to \(agentName)")
                .font(DS.Typography.heading2)

            if let agent = store.selectedAgent {
                Text(agent.description)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Connection state
            if store.isConnected {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DS.Color.success)
                        .font(.title2)
                    Text("Connected to \(store.connectedAgentName ?? agentName)!")
                        .font(DS.Typography.bodyMedium)
                        .foregroundColor(DS.Color.success)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(DS.Color.success.opacity(DS.Color.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            } else if store.isConnecting {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity)
            } else if let error = store.connectionError {
                VStack(spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DS.Color.error)
                        Text(error)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Color.error)
                    }
                    Button("Retry") {
                        store.send(.retryConnection)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    store.send(.connectToAgent)
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
            }

            // Navigation
            HStack {
                stepDots
                Spacer()
                Button("Back") {
                    store.send(.previousStep)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Next") {
                    store.send(.nextStep)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!store.isConnected)
                .keyboardShortcut(.return)
            }

            HStack {
                Spacer()
                Button("Skip Tour") {
                    store.send(.skipAll)
                }
                .buttonStyle(.plain)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Color.textSecondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .position(x: windowSize.width / 2, y: windowSize.height / 2)
    }

    // MARK: - Tooltip Card

    @ViewBuilder
    private var tooltipCard: some View {
        let step = store.currentStep
        let tooltipPos = tooltipPosition(for: step)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(step.title)
                .font(.headline)

            Text(step.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                stepDots

                Spacer()

                if !store.isFirstStep {
                    Button("Back") {
                        store.send(.previousStep)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(store.isLastStep ? "Done" : "Next") {
                    store.send(.nextStep)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return)
            }

            HStack {
                Spacer()
                Button("Skip Tour") {
                    store.send(.skipAll)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .position(tooltipPos)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var stepDots: some View {
        HStack(spacing: 4) {
            ForEach(Array(store.steps.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == store.currentStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Geometry Helpers

    // Constants matching CuttleView
    private static let collapsedSize: CGFloat = 48
    private static let margin: CGFloat = 8
    private static let topInset: CGFloat = 52

    /// The clamped chat window frame, mirroring CuttleView.expandedPosition exactly.
    private var chatWindowFrame: CGRect {
        let w = chatSize.width
        let h = chatSize.height
        let blobOverhead = Self.collapsedSize / 2 + 4
        let minChatCenterY = Self.topInset + blobOverhead + h / 2

        var cx = cuttlePosition.x + w / 2 - Self.collapsedSize / 2
        var cy = cuttlePosition.y + h / 2 + Self.collapsedSize

        if cx + w / 2 > windowSize.width - Self.margin {
            cx = windowSize.width - Self.margin - w / 2
        }
        if cx - w / 2 < Self.margin {
            cx = Self.margin + w / 2
        }
        if cy + h / 2 > windowSize.height - Self.margin {
            cy = cuttlePosition.y - h / 2 - Self.collapsedSize
        }
        if cy < minChatCenterY {
            cy = minChatCenterY
        }

        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// The blob's visual center, accounting for the expanded offset.
    /// When expanded, derives from the clamped chat position (not the raw cuttlePosition).
    private var blobCenter: CGPoint {
        if cuttleIsExpanded {
            let frame = chatWindowFrame
            return CGPoint(
                x: frame.midX,
                y: frame.minY - Self.collapsedSize / 2 - 4
            )
        }
        return cuttlePosition
    }

    private func spotlightFrames(for step: CuttleOnboardingFeature.OnboardingStep) -> [CGRect] {
        switch step.spotlightTarget {
        case .blob:
            let size: CGFloat = 64
            let center = blobCenter
            return [CGRect(
                x: center.x - size / 2,
                y: center.y - size / 2,
                width: size,
                height: size
            )]
        case .chatWindow:
            return [chatWindowFrame]
        case .dockTargets:
            return dockTargetFrames()
        case .none:
            return [.zero]
        }
    }

    /// Adjusts a drop zone frame from the cuttle-window coordinate space to the overlay's
    /// local coordinate space by subtracting the macOS toolbar safe area offset.
    private func adjustedFrame(_ frame: CGRect) -> CGRect {
        frame.offsetBy(dx: 0, dy: -safeAreaTopInset)
    }

    /// Returns separate spotlight rects for the filter bar, swim lane headers, and a sample job card.
    /// All drop zone frames are adjusted from the cuttle-window coordinate space to the overlay's
    /// local coordinate space.
    private func dockTargetFrames() -> [CGRect] {
        var frames: [CGRect] = []

        let statusGlobalZones = dropZones.filter { zone in
            if case .global = zone.context { return true }
            if case .status = zone.context { return true }
            return false
        }

        // Filter pills are short capsules (< 45pt tall); kanban headers are taller
        let pillHeight: CGFloat = 45

        // 1. Filter bar: union of short pill-sized zones (filter row at the top)
        let filterFrames = statusGlobalZones.filter { $0.frame.height < pillHeight }.map(\.frame)
        if let first = filterFrames.first {
            let union = filterFrames.dropFirst().reduce(first) { $0.union($1) }
            frames.append(adjustedFrame(union))
        } else {
            frames.append(CGRect(x: 180, y: 80, width: windowSize.width - 200, height: 40))
        }

        // 2. Swim lane headers: union of taller status zones (excluding sidebar global)
        let headerFrames = statusGlobalZones.filter { zone in
            if case .status = zone.context { return zone.frame.height >= pillHeight }
            return false
        }.map(\.frame)
        if let first = headerFrames.first {
            let union = headerFrames.dropFirst().reduce(first) { $0.union($1) }
            frames.append(adjustedFrame(union))
        }

        // 3. A sample job card: first job drop zone, or a placeholder for fresh users
        if let firstJob = dropZones.first(where: { if case .job = $0.context { return true }; return false }) {
            frames.append(adjustedFrame(firstJob.frame))
        } else {
            frames.append(CGRect(x: 170, y: 140, width: 240, height: 120))
        }

        return frames
    }

    /// Bounding rect of all spotlights, used for tooltip placement.
    private func spotlightBounds(for step: CuttleOnboardingFeature.OnboardingStep) -> CGRect {
        let rects = spotlightFrames(for: step).filter { $0 != .zero }
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private func tooltipPosition(for step: CuttleOnboardingFeature.OnboardingStep) -> CGPoint {
        let spotlight = spotlightBounds(for: step)

        if spotlight == .zero {
            // Centered card
            return CGPoint(x: windowSize.width / 2, y: windowSize.height / 2)
        }

        let tooltipWidth: CGFloat = 300
        let tooltipHeight: CGFloat = 180
        let margin: CGFloat = 20

        // Try to place tooltip to the right of the spotlight
        let rightX = spotlight.maxX + margin + tooltipWidth / 2
        if rightX + tooltipWidth / 2 < windowSize.width - margin {
            return CGPoint(x: rightX, y: spotlight.midY)
        }

        // Fall back to left
        let leftX = spotlight.minX - margin - tooltipWidth / 2
        if leftX - tooltipWidth / 2 > margin {
            return CGPoint(x: leftX, y: spotlight.midY)
        }

        // Fall back to below
        return CGPoint(
            x: spotlight.midX,
            y: spotlight.maxY + margin + tooltipHeight / 2
        )
    }
}
