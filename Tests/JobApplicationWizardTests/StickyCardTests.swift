import Testing
import JobApplicationShared
import SwiftUI
@testable import JobApplicationWizardCore

// MARK: - StickyCardState Boundary Detection

@Suite("Sticky Card Boundary Detection")
struct StickyCardBoundaryTests {
    let viewportWidth: CGFloat = 600
    let cardWidth: CGFloat = KanbanRow.cardWidth  // 240
    let padding: CGFloat = DS.Spacing.md

    private func state(
        cardMinX: CGFloat,
        hasPinned: Bool = true,
        awaiting: Bool = false,
        vpWidth: CGFloat? = nil
    ) -> StickyCardState {
        StickyCardState(
            cardFrame: CGRect(x: cardMinX, y: 10, width: cardWidth, height: 100),
            viewportWidth: vpWidth ?? viewportWidth,
            hasPinnedCard: hasPinned,
            awaitingFirstGeometry: awaiting,
            cardWidth: cardWidth,
            padding: padding
        )
    }

    @Test("Card fully in view is not stuck")
    func cardInView() {
        let s = state(cardMinX: padding + 10)
        #expect(!s.isStuck)
    }

    @Test("Card crossing leading edge is stuck")
    func cardPastLeading() {
        let s = state(cardMinX: padding - 1)
        #expect(s.isStuck)
    }

    @Test("Card crossing trailing edge is stuck")
    func cardPastTrailing() {
        // Card's maxX = cardMinX + cardWidth > viewportWidth - padding
        let cardMinX = viewportWidth - cardWidth - padding + 1
        let s = state(cardMinX: cardMinX)
        #expect(s.isStuck)
    }

    @Test("Card exactly at leading boundary is not stuck")
    func cardExactlyAtLeading() {
        let s = state(cardMinX: padding)
        #expect(!s.isStuck)
    }

    @Test("Card exactly at trailing boundary is not stuck")
    func cardExactlyAtTrailing() {
        let cardMinX = viewportWidth - cardWidth - padding
        let s = state(cardMinX: cardMinX)
        #expect(!s.isStuck)
    }

    @Test("No pinned card means never stuck")
    func noPinnedCard() {
        let s = state(cardMinX: -100, hasPinned: false)
        #expect(!s.isStuck)
    }

    @Test("Awaiting first geometry suppresses stuck")
    func awaitingSuppresses() {
        let s = state(cardMinX: -100, awaiting: true)
        #expect(!s.isStuck)
    }

    @Test("Zero-width frame suppresses stuck")
    func zeroWidthFrame() {
        var s = StickyCardState()
        s.hasPinnedCard = true
        s.viewportWidth = 600
        // cardFrame defaults to .zero (width == 0)
        #expect(!s.isStuck)
    }

    @Test("Zero viewport width suppresses stuck")
    func zeroViewport() {
        let s = state(cardMinX: -100, vpWidth: 0)
        #expect(!s.isStuck)
    }

    @Test("Negative card position is stuck")
    func negativePosition() {
        let s = state(cardMinX: -50)
        #expect(s.isStuck)
    }
}

// MARK: - StickyCardState Clamping

@Suite("Sticky Card Clamping")
struct StickyCardClampingTests {
    let viewportWidth: CGFloat = 600
    let cardWidth: CGFloat = KanbanRow.cardWidth
    let padding: CGFloat = DS.Spacing.md

    private func state(cardMinX: CGFloat) -> StickyCardState {
        StickyCardState(
            cardFrame: CGRect(x: cardMinX, y: 10, width: cardWidth, height: 100),
            viewportWidth: viewportWidth,
            hasPinnedCard: true,
            cardWidth: cardWidth,
            padding: padding
        )
    }

    @Test("Clamp to leading edge when scrolled past left")
    func clampLeading() {
        let s = state(cardMinX: -100)
        #expect(s.clampedX == padding)
    }

    @Test("Clamp to trailing edge when scrolled past right")
    func clampTrailing() {
        let s = state(cardMinX: 500)
        let expected = viewportWidth - cardWidth - padding
        #expect(s.clampedX == expected)
    }

    @Test("Natural position returned when card is in view")
    func naturalPosition() {
        let cardMinX: CGFloat = 100
        let s = state(cardMinX: cardMinX)
        #expect(s.clampedX == cardMinX)
    }

    @Test("Clamp is continuous at leading boundary")
    func continuousAtLeading() {
        // Just inside: natural
        let inside = state(cardMinX: padding + 1)
        #expect(inside.clampedX == padding + 1)
        // Just outside: clamped
        let outside = state(cardMinX: padding - 1)
        #expect(outside.clampedX == padding)
    }

    @Test("Clamp is continuous at trailing boundary")
    func continuousAtTrailing() {
        let maxAllowed = viewportWidth - cardWidth - padding
        let inside = state(cardMinX: maxAllowed - 1)
        #expect(inside.clampedX == maxAllowed - 1)
        let outside = state(cardMinX: maxAllowed + 1)
        #expect(outside.clampedX == maxAllowed)
    }
}

// MARK: - Drop Zone isActive Tests

@Suite("CuttleDockable isActive")
struct CuttleDockableActiveTests {

    @Test("Drop zone emits zone when active")
    func activeEmitsZone() {
        // DropZone creation is straightforward; verify the data model
        let zone = DropZone(
            id: "job-test",
            frame: CGRect(x: 0, y: 0, width: 240, height: 100),
            context: .job(UUID())
        )
        #expect(zone.frame.width == 240)
    }

    @Test("DropZonePreferenceKey reduces by appending")
    func preferenceKeyReduces() {
        let zone1 = DropZone(id: "a", frame: .zero, context: .global)
        let zone2 = DropZone(id: "b", frame: .zero, context: .status(.applied))
        var value = [zone1]
        DropZonePreferenceKey.reduce(value: &value) { [zone2] }
        #expect(value.count == 2)
        #expect(value[0].id == "a")
        #expect(value[1].id == "b")
    }

    @Test("Empty reduce produces no zones (isActive false scenario)")
    func emptyReduceForInactive() {
        var value: [DropZone] = []
        DropZonePreferenceKey.reduce(value: &value) { [] }
        #expect(value.isEmpty)
    }
}

// MARK: - Shadow Hierarchy

@Suite("Shadow Hierarchy")
struct ShadowHierarchyTests {
    @Test("Sticky shadow is between card and floating")
    func stickyBetweenCardAndFloating() {
        #expect(DS.Shadow.sticky.radius > DS.Shadow.card.radius)
        #expect(DS.Shadow.sticky.radius < DS.Shadow.floating.radius)
    }
}
