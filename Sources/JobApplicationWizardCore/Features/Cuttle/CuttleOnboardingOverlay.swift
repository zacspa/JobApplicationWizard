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
    @Environment(\.openSettings) private var openSettings

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

            // Tooltip card
            tooltipCard
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
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: expanded.width, height: expanded.height)
                                    .position(x: expanded.midX, y: expanded.midY)
                                    .blendMode(.destinationOut)
                            }
                        }
                    }
                    .compositingGroup()
            }
    }

    // MARK: - Tooltip Card

    @ViewBuilder
    private var tooltipCard: some View {
        let step = store.currentStep
        let tooltipPos = tooltipPosition(for: step)

        VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.headline)

            Text(step.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if step == .aiSetup {
                Button("Open Settings") {
                    openSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(
                            name: .selectSettingsTab,
                            object: SettingsTab.aiProvider
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack {
                // Step dots
                HStack(spacing: 4) {
                    ForEach(Array(store.steps.enumerated()), id: \.offset) { index, _ in
                        Circle()
                            .fill(index == store.currentStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

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
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .position(tooltipPos)
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
