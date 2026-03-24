import XCTest
import SwiftUI
import SnapshotTesting
@testable import JobApplicationWizardCore

// MARK: - Snapshot Test Helpers

/// A `.dump`-based snapshotting that strips platform-variable internals:
/// ISO-8601 timestamps, resolved color components (linearRed/Green/Blue, opacity, _headroom),
/// and nested color base representations that differ across macOS/Xcode versions.
private let stableDump: Snapshotting<Any, String> = {
    let base = Snapshotting<Any, String>.dump
    let volatilePatterns: [String] = [
        #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"#,
        #"- linearRed:"#,
        #"- linearGreen:"#,
        #"- linearBlue:"#,
        #"- opacity: \d"#,
        #"- _headroom:"#,
        #"▿ base: #[0-9A-Fa-f]"#,
    ]
    return Snapshotting<Any, String>(
        pathExtension: base.pathExtension,
        diffing: base.diffing
    ) { value in
        base.snapshot(value).map { text in
            text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { line in
                    !volatilePatterns.contains { pattern in
                        line.range(of: pattern, options: .regularExpression) != nil
                    }
                }
                .joined(separator: "\n")
        }
    }
}()

/// Asserts a text-based view hierarchy snapshot using the `.dump` strategy.
/// This is environment-agnostic (no pixel rendering), so it works across different Macs.
private func assertViewDump<V: View>(
    _ view: V,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: view,
        as: .dump,
        file: file, testName: testName, line: line
    )
}

/// Variant that strips volatile timestamp lines for views containing `@State` date properties.
private func assertViewDumpStable<V: View>(
    _ view: V,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
) {
    assertSnapshot(
        of: view as Any,
        as: stableDump,
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

        assertViewDump(view)
    }

    func testOutlinedFieldFilled() {
        let view = Text("Acme Corp")
            .outlinedField("Company", isEmpty: false)
            .padding()

        assertViewDump(view)
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

        assertViewDump(view)
    }

    func testCardSelected() {
        let view = VStack(alignment: .leading) {
            Text("Acme Corp").font(DS.Typography.bodySemibold)
            Text("Senior Engineer").font(DS.Typography.caption)
        }
        .frame(width: 200)
        .cardStyle(isSelected: true, tintColor: .blue)

        assertViewDump(view)
    }

    func testCardHovered() {
        let view = VStack(alignment: .leading) {
            Text("Acme Corp").font(DS.Typography.bodySemibold)
            Text("Senior Engineer").font(DS.Typography.caption)
        }
        .frame(width: 200)
        .cardStyle(isHovered: true)

        assertViewDump(view)
    }
}

// MARK: - Button Style Snapshots

final class ButtonStyleSnapshotTests: XCTestCase {
    func testPillButtonUnselected() {
        let view = Button("Applied") {}
            .buttonStyle(PillButtonStyle())
            .padding()

        assertViewDump(view)
    }

    func testPillButtonSelected() {
        let view = Button("Applied") {}
            .buttonStyle(PillButtonStyle(isSelected: true))
            .padding()

        assertViewDump(view)
    }

    func testPillButtonCustomTint() {
        let view = Button("Interview") {}
            .buttonStyle(PillButtonStyle(isSelected: true, tint: .purple))
            .padding()

        assertViewDump(view)
    }

    func testGhostButton() {
        let view = Button {} label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(GhostButtonStyle())
        .padding()

        assertViewDump(view)
    }

    func testActionButton() {
        let view = Button {} label: {
            Label("Save PDF", systemImage: "doc.fill")
        }
        .buttonStyle(DSActionButtonStyle())
        .padding()

        assertViewDump(view)
    }
}

// MARK: - Glass Surface Snapshots

final class GlassSurfaceSnapshotTests: XCTestCase {
    func testGlassSurfaceDefault() {
        let view = Text("Glass Panel")
            .font(DS.Typography.body)
            .padding(DS.Spacing.xl)
            .glassSurface()

        assertViewDumpStable(view)
    }

    func testGlassSurfaceNoBorder() {
        let view = Text("No Border")
            .font(DS.Typography.body)
            .padding(DS.Spacing.xl)
            .glassSurface(border: false)

        assertViewDumpStable(view)
    }
}

// MARK: - DSOutlinedTextEditor Snapshots

final class DSOutlinedTextEditorSnapshotTests: XCTestCase {
    func testOutlinedTextEditorEmpty() {
        let view = DSOutlinedTextEditor("Notes", text: .constant(""), minHeight: 60)
            .padding()

        assertViewDump(view)
    }

    func testOutlinedTextEditorFilled() {
        let view = DSOutlinedTextEditor("Notes", text: .constant("Meeting went well, discussed next steps."), minHeight: 60)
            .padding()

        assertViewDump(view)
    }
}

// MARK: - DSDateField Snapshots

final class DSDateFieldSnapshotTests: XCTestCase {
    func testDateFieldNil() {
        let view = DSDateField("Interview Date", date: .constant(nil))
            .padding()

        assertViewDumpStable(view)
    }

    func testDateFieldSet() {
        let date = Date(timeIntervalSince1970: 1774000000)
        let view = DSDateField("Interview Date", date: .constant(date))
            .padding()

        assertViewDumpStable(view)
    }
}

// MARK: - Iridescent Sheen Snapshots

final class IridescentSheenSnapshotTests: XCTestCase {
    func testSheenActive() {
        let view = Text("Cuttle docked here")
            .padding(DS.Spacing.xl)
            .glassSurface()
            .iridescentSheen(isActive: true)

        assertViewDumpStable(view)
    }

    func testSheenInactive() {
        let view = Text("No Cuttle")
            .padding(DS.Spacing.xl)
            .glassSurface()
            .iridescentSheen(isActive: false)

        assertViewDumpStable(view)
    }
}
