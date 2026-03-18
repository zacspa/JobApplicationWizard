import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import XCTest
@testable import JobApplicationWizardCore

@MainActor
final class CuttleOnboardingSnapshotTests: XCTestCase {

    private let windowSize = CGSize(width: 800, height: 600)
    private let defaultPosition = CGPoint(x: 400, y: 300)

    // MARK: - Helpers

    private func makeHostingController(
        step: CuttleOnboardingFeature.OnboardingStep,
        cuttlePosition: CGPoint? = nil,
        cuttleIsExpanded: Bool? = nil,
        dropZones: [DropZone] = []
    ) -> NSHostingController<some View> {
        let isExpanded = cuttleIsExpanded ?? (step == .chatBasics || step == .resize)
        var state = CuttleOnboardingFeature.State()
        state.isActive = true
        state.currentStep = step

        let store = Store(initialState: state) { CuttleOnboardingFeature() }

        let view = CuttleOnboardingOverlay(
            store: store,
            cuttlePosition: cuttlePosition ?? defaultPosition,
            cuttleIsExpanded: isExpanded,
            windowSize: windowSize,
            dropZones: dropZones
        )
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Color.white)

        let hc = NSHostingController(rootView: view)
        hc.view.frame = CGRect(origin: .zero, size: windowSize)
        return hc
    }

    private func mockDropZones() -> [DropZone] {
        let statuses: [JobStatus] = [.wishlist, .applied, .phoneScreen, .interview, .offer]
        var zones: [DropZone] = [
            DropZone(id: "global", frame: CGRect(x: 16, y: 80, width: 80, height: 30), context: .global)
        ]
        for (i, status) in statuses.enumerated() {
            zones.append(DropZone(
                id: "status-\(status.rawValue)",
                frame: CGRect(x: 110 + CGFloat(i) * 110, y: 80, width: 100, height: 30),
                context: .status(status)
            ))
        }
        return zones
    }

    // MARK: - Step Tests

    func testMeetCuttle() {
        let vc = makeHostingController(step: .meetCuttle)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testExpandCollapse() {
        let vc = makeHostingController(step: .expandCollapse)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testChatBasics() {
        let vc = makeHostingController(step: .chatBasics, cuttleIsExpanded: true)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testDragToDock() {
        let vc = makeHostingController(step: .dragToDock, cuttleIsExpanded: false, dropZones: mockDropZones())
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testCarryOrFresh() {
        let vc = makeHostingController(step: .carryOrFresh, cuttleIsExpanded: false)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testResize() {
        let vc = makeHostingController(step: .resize, cuttleIsExpanded: true)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testAiSetup() {
        let vc = makeHostingController(step: .aiSetup, cuttleIsExpanded: false)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    // MARK: - Edge Case: Clamping Tests

    func testBlobSpotlightNearRightEdge() {
        let vc = makeHostingController(
            step: .meetCuttle,
            cuttlePosition: CGPoint(x: 750, y: 300),
            cuttleIsExpanded: false
        )
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testBlobSpotlightNearBottom() {
        let vc = makeHostingController(
            step: .chatBasics,
            cuttlePosition: CGPoint(x: 400, y: 550),
            cuttleIsExpanded: true
        )
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testBlobSpotlightNearTopLeft() {
        let vc = makeHostingController(
            step: .chatBasics,
            cuttlePosition: CGPoint(x: 50, y: 80),
            cuttleIsExpanded: true
        )
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }
}
