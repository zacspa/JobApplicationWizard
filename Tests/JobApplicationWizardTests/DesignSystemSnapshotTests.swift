import XCTest
import SwiftUI
import SnapshotTesting
@testable import JobApplicationWizardCore

// MARK: - Snapshot Test Helpers

private func hostView<V: View>(_ view: V, width: CGFloat = 300, height: CGFloat = 60, appearance: NSAppearance.Name = .darkAqua) -> NSView {
    let hostingView = NSHostingView(rootView: view.frame(width: width, height: height))
    hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    hostingView.appearance = NSAppearance(named: appearance)
    return hostingView
}

/// Asserts snapshots in both dark and light mode with suffixed names.
private func assertBothModes<V: View>(
    _ view: V,
    width: CGFloat = 300,
    height: CGFloat = 60,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: hostView(view, width: width, height: height, appearance: .darkAqua),
        as: .image,
        named: "dark",
        file: file, testName: testName, line: line
    )
    assertSnapshot(
        of: hostView(view, width: width, height: height, appearance: .aqua),
        as: .image,
        named: "light",
        file: file, testName: testName, line: line
    )
}

// MARK: - Outlined Field Snapshots

final class OutlinedFieldSnapshotTests: XCTestCase {
    func testOutlinedFieldEmpty() {
        let view = Text("Placeholder")
            .foregroundColor(.secondary)
            .outlinedField("Company", isEmpty: true)
            .padding()

        assertBothModes(view, width: 300, height: 50)
    }

    func testOutlinedFieldFilled() {
        let view = Text("Acme Corp")
            .outlinedField("Company", isEmpty: false)
            .padding()

        assertBothModes(view, width: 300, height: 50)
    }
}

// MARK: - Card Modifier Snapshots

final class CardModifierSnapshotTests: XCTestCase {
    func testCardDefault() {
        let view = VStack(alignment: .leading) {
            Text("Acme Corp").font(DS.Typography.bodySemibold)
            Text("Senior Engineer").font(DS.Typography.caption)
        }
        .frame(width: 200)
        .cardStyle()

        assertBothModes(view, width: 240, height: 80)
    }

    func testCardSelected() {
        let view = VStack(alignment: .leading) {
            Text("Acme Corp").font(DS.Typography.bodySemibold)
            Text("Senior Engineer").font(DS.Typography.caption)
        }
        .frame(width: 200)
        .cardStyle(isSelected: true, tintColor: .blue)

        assertBothModes(view, width: 240, height: 80)
    }

    func testCardHovered() {
        let view = VStack(alignment: .leading) {
            Text("Acme Corp").font(DS.Typography.bodySemibold)
            Text("Senior Engineer").font(DS.Typography.caption)
        }
        .frame(width: 200)
        .cardStyle(isHovered: true)

        assertBothModes(view, width: 240, height: 80)
    }
}

// MARK: - Button Style Snapshots

final class ButtonStyleSnapshotTests: XCTestCase {
    func testPillButtonUnselected() {
        let view = Button("Applied") {}
            .buttonStyle(PillButtonStyle())
            .padding()

        assertBothModes(view, width: 120, height: 40)
    }

    func testPillButtonSelected() {
        let view = Button("Applied") {}
            .buttonStyle(PillButtonStyle(isSelected: true))
            .padding()

        assertBothModes(view, width: 120, height: 40)
    }

    func testPillButtonCustomTint() {
        let view = Button("Interview") {}
            .buttonStyle(PillButtonStyle(isSelected: true, tint: .purple))
            .padding()

        assertBothModes(view, width: 120, height: 40)
    }

    func testGhostButton() {
        let view = Button {} label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(GhostButtonStyle())
        .padding()

        assertBothModes(view, width: 100, height: 40)
    }

    func testActionButton() {
        let view = Button {} label: {
            Label("Save PDF", systemImage: "doc.fill")
        }
        .buttonStyle(DSActionButtonStyle())
        .padding()

        assertBothModes(view, width: 140, height: 40)
    }
}

// MARK: - Glass Surface Snapshots

final class GlassSurfaceSnapshotTests: XCTestCase {
    func testGlassSurfaceDefault() {
        let view = Text("Glass Panel")
            .font(DS.Typography.body)
            .padding(DS.Spacing.xl)
            .glassSurface()

        assertBothModes(view, width: 200, height: 80)
    }

    func testGlassSurfaceNoBorder() {
        let view = Text("No Border")
            .font(DS.Typography.body)
            .padding(DS.Spacing.xl)
            .glassSurface(border: false)

        assertBothModes(view, width: 200, height: 80)
    }
}

// MARK: - DSOutlinedTextEditor Snapshots

final class DSOutlinedTextEditorSnapshotTests: XCTestCase {
    func testOutlinedTextEditorEmpty() {
        let view = DSOutlinedTextEditor("Notes", text: .constant(""), minHeight: 60)
            .padding()

        assertBothModes(view, width: 300, height: 100)
    }

    func testOutlinedTextEditorFilled() {
        let view = DSOutlinedTextEditor("Notes", text: .constant("Meeting went well, discussed next steps."), minHeight: 60)
            .padding()

        assertBothModes(view, width: 300, height: 100)
    }
}

// MARK: - DSDateField Snapshots

final class DSDateFieldSnapshotTests: XCTestCase {
    func testDateFieldNil() {
        let view = DSDateField("Interview Date", date: .constant(nil))
            .padding()

        assertBothModes(view, width: 300, height: 50)
    }

    func testDateFieldSet() {
        let date = Date(timeIntervalSince1970: 1774000000)
        let view = DSDateField("Interview Date", date: .constant(date))
            .padding()

        assertBothModes(view, width: 300, height: 50)
    }
}

// MARK: - Iridescent Sheen Snapshots

final class IridescentSheenSnapshotTests: XCTestCase {
    func testSheenActive() {
        let view = Text("Cuttle docked here")
            .padding(DS.Spacing.xl)
            .glassSurface()
            .iridescentSheen(isActive: true)

        assertBothModes(view, width: 250, height: 80)
    }

    func testSheenInactive() {
        let view = Text("No Cuttle")
            .padding(DS.Spacing.xl)
            .glassSurface()
            .iridescentSheen(isActive: false)

        assertBothModes(view, width: 250, height: 80)
    }
}
