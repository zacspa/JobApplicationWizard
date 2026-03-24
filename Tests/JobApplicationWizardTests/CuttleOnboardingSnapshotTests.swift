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
            // Filter bar "All" pill (short, pill-height)
            DropZone(id: "global", frame: CGRect(x: 196, y: 88, width: 80, height: 28), context: .global)
        ]
        for (i, status) in statuses.enumerated() {
            // Filter bar pill for each status (short, pill-height)
            zones.append(DropZone(
                id: "filter-\(status.rawValue)",
                frame: CGRect(x: 290 + CGFloat(i) * 110, y: 88, width: 100, height: 28),
                context: .status(status)
            ))
            // Swim lane header (tall, in left column below filter bar)
            zones.append(DropZone(
                id: "status-\(status.rawValue)",
                frame: CGRect(x: 196, y: 140 + CGFloat(i) * 90, width: 140, height: 64),
                context: .status(status)
            ))
        }
        // Sample job card (right of the swim lane headers, in the first row)
        let sampleJobId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        zones.append(DropZone(
            id: "job-\(sampleJobId.uuidString)",
            frame: CGRect(x: 360, y: 150, width: 240, height: 110),
            context: .job(sampleJobId)
        ))
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

    func testDiscoverAgent() {
        let vc = makeHostingController(step: .discoverAgent, cuttleIsExpanded: false)
        assertSnapshot(of: vc, as: .image(size: windowSize))
    }

    func testConnectAgent() {
        let vc = makeHostingController(step: .connectAgent, cuttleIsExpanded: false)
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
