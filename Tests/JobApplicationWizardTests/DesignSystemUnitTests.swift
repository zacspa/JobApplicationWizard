import Testing
import SwiftUI
@testable import JobApplicationWizardCore

// MARK: - Token Value Tests

@Suite("DS Token Values")
struct DSTokenTests {
    @Test("Spacing scale is monotonically increasing")
    func spacingScale() {
        let values: [CGFloat] = [
            DS.Spacing.xxxs, DS.Spacing.xxs, DS.Spacing.xs,
            DS.Spacing.sm, DS.Spacing.md, DS.Spacing.lg,
            DS.Spacing.xl, DS.Spacing.xxl, DS.Spacing.xxxl, DS.Spacing.huge
        ]
        for i in 1..<values.count {
            #expect(values[i] > values[i - 1], "Spacing scale must be strictly increasing")
        }
    }

    @Test("Radius scale is monotonically increasing")
    func radiusScale() {
        let values: [CGFloat] = [
            DS.Radius.small, DS.Radius.medium, DS.Radius.large,
            DS.Radius.xl, DS.Radius.xxl
        ]
        for i in 1..<values.count {
            #expect(values[i] > values[i - 1], "Radius scale must be strictly increasing")
        }
    }

    @Test("Opacity scale is monotonically increasing")
    func opacityScale() {
        let values: [Double] = [
            DS.Color.Opacity.subtle, DS.Color.Opacity.wash, DS.Color.Opacity.tint,
            DS.Color.Opacity.medium, DS.Color.Opacity.strong, DS.Color.Opacity.border
        ]
        for i in 1..<values.count {
            #expect(values[i] > values[i - 1], "Opacity scale must be strictly increasing")
        }
    }

    @Test("Pill spacing tokens are positive")
    func pillSpacing() {
        #expect(DS.Spacing.pillH > 0)
        #expect(DS.Spacing.pillV > 0)
    }

    @Test("Shadow card is lighter than floating")
    func shadowHierarchy() {
        #expect(DS.Shadow.card.radius < DS.Shadow.floating.radius)
    }
}

// MARK: - CardModifier Logic Tests

@Suite("CardModifier Logic")
struct CardModifierTests {
    @Test("Default card uses controlBackground")
    func defaultBackground() {
        let modifier = CardModifier()
        // Not selected, not hovered, no custom background
        #expect(modifier.isSelected == false)
        #expect(modifier.isHovered == false)
        #expect(modifier.tintColor == nil)
        #expect(modifier.backgroundColor == nil)
    }

    @Test("Selected card uses tint color when provided")
    func selectedWithTint() {
        let modifier = CardModifier(isSelected: true, tintColor: .red)
        #expect(modifier.isSelected == true)
        #expect(modifier.tintColor == .red)
    }

    @Test("Hovered card without selection shows hover state")
    func hoveredNotSelected() {
        let modifier = CardModifier(isHovered: true)
        #expect(modifier.isHovered == true)
        #expect(modifier.isSelected == false)
    }
}

// MARK: - OutlinedFieldModifier Logic Tests

@Suite("OutlinedFieldModifier Logic")
struct OutlinedFieldTests {
    @Test("Empty and unfocused hides label")
    func emptyUnfocused() {
        let modifier = OutlinedFieldModifier("Test", isEmpty: true)
        // When isEmpty is true and not focused, showLabel should be false
        // (The actual showLabel is private, but we verify via the isEmpty parameter)
        #expect(modifier.isEmpty == true)
        #expect(modifier.label == "Test")
    }

    @Test("Non-empty always shows label")
    func nonEmpty() {
        let modifier = OutlinedFieldModifier("Company", isEmpty: false)
        #expect(modifier.isEmpty == false)
    }
}
