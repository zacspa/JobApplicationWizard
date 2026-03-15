import SwiftUI
import ComposableArchitecture

public struct CuttleOnboardingOverlay: View {
    let store: StoreOf<CuttleOnboardingFeature>
    let cuttlePosition: CGPoint
    let cuttleIsExpanded: Bool
    let windowSize: CGSize

    public init(
        store: StoreOf<CuttleOnboardingFeature>,
        cuttlePosition: CGPoint,
        cuttleIsExpanded: Bool,
        windowSize: CGSize
    ) {
        self.store = store
        self.cuttlePosition = cuttlePosition
        self.cuttleIsExpanded = cuttleIsExpanded
        self.windowSize = windowSize
    }

    public var body: some View {
        ZStack {
            // Dimming layer with spotlight cutout
            dimmingLayer
                .allowsHitTesting(false)

            // Tooltip card
            tooltipCard
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: store.currentStep)
    }

    // MARK: - Dimming Layer

    @ViewBuilder
    private var dimmingLayer: some View {
        let spotlightRect = spotlightFrame(for: store.currentStep)
        Canvas { context, size in
            // Full dim
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.4))
            )
            // Cut out the spotlight with rounded corners
            if spotlightRect != .zero {
                let inset: CGFloat = -12
                let expanded = spotlightRect.insetBy(dx: inset, dy: inset)
                context.blendMode = .destinationOut
                context.fill(
                    Path(roundedRect: expanded, cornerRadius: 12),
                    with: .color(.white)
                )
            }
        }
        .compositingGroup()
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
                    store.send(.delegate(.openSettings))
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

    private func spotlightFrame(for step: CuttleOnboardingFeature.OnboardingStep) -> CGRect {
        switch step.spotlightTarget {
        case .blob:
            let size: CGFloat = 64
            return CGRect(
                x: cuttlePosition.x - size / 2,
                y: cuttlePosition.y - size / 2,
                width: size,
                height: size
            )
        case .chatWindow:
            // Approximate chat window position relative to blob
            let chatWidth: CGFloat = 380
            let chatHeight: CGFloat = 480
            let chatX = cuttlePosition.x - chatWidth / 2
            let chatY = cuttlePosition.y + 40
            return CGRect(x: chatX, y: chatY, width: chatWidth, height: chatHeight)
        case .filterBar:
            // Filter bar is near the top, full width
            return CGRect(x: 200, y: 80, width: windowSize.width - 220, height: 40)
        case .none:
            return .zero
        }
    }

    private func tooltipPosition(for step: CuttleOnboardingFeature.OnboardingStep) -> CGPoint {
        let spotlight = spotlightFrame(for: step)

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
