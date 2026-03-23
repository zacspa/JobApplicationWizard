import XCTest
import SwiftUI
import ComposableArchitecture
@testable import JobApplicationWizardCore

@MainActor
final class CuttleExpansionPerformanceTests: XCTestCase {

    func testExpandCollapsePerformance() {
        let store = withDependencies {
            $0.claudeClient.chat = { _, _, _, _ in
                ("mock", AITokenUsage(inputTokens: 0, outputTokens: 0), nil)
            }
        } operation: {
            Store(initialState: CuttleFeature.State()) { CuttleFeature() }
        }
        let hostingView = NSHostingView(
            rootView: CuttleView(store: store)
                .frame(width: 800, height: 600)
                .coordinateSpace(name: "cuttle-window")
        )
        hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        hostingView.layoutSubtreeIfNeeded()

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            store.send(.toggleExpanded)
            hostingView.layoutSubtreeIfNeeded()

            // Reset for next iteration
            store.send(.toggleExpanded)
            hostingView.layoutSubtreeIfNeeded()
        }
    }
}
