import SwiftUI

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A ViewModifier that adds an outlined border with a floating label on the
/// top-leading edge. When empty and unfocused, the border is closed. Focused
/// state accents the border and label with the lane color.
public struct OutlinedFieldModifier: ViewModifier {
    public var label: String
    public var isEmpty: Bool

    @FocusState private var isFocused: Bool
    @State private var measuredLabelWidth: CGFloat = 0
    @Environment(\.dsLaneAccent) private var laneAccent

    private let gapPad: CGFloat = 4
    private let gapInset: CGFloat = 8

    private var showLabel: Bool {
        isFocused || !isEmpty
    }

    public init(_ label: String, isEmpty: Bool) {
        self.label = label
        self.isEmpty = isEmpty
    }

    private var borderColor: Color {
        isFocused ? laneAccent : DS.Color.border
    }

    private var labelColor: Color {
        isFocused ? laneAccent : DS.Color.textSecondary
    }

    public func body(content: Content) -> some View {
        content
            .font(DS.Typography.footnote)
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .padding(.top, showLabel ? DS.Spacing.xxxs : 0)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            .focused($isFocused)
            .overlay(
                ZStack(alignment: .topLeading) {
                    if showLabel {
                        FieldBorder(labelWidth: measuredLabelWidth + gapPad * 2, labelOffset: gapInset)
                            .stroke(borderColor, lineWidth: isFocused ? 1.5 : 1)

                        Text(label)
                            .font(DS.Typography.micro)
                            .foregroundColor(labelColor)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: LabelWidthKey.self, value: geo.size.width)
                                }
                            )
                            .offset(x: gapInset + gapPad, y: -5)
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.small)
                            .stroke(borderColor, lineWidth: 1)
                    }
                }
            )
            .onPreferenceChange(LabelWidthKey.self) { measuredLabelWidth = $0 }
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: showLabel)
    }
}

extension View {
    /// Adds an outlined border with a floating label that appears when focused or non-empty.
    public func outlinedField(_ label: String, isEmpty: Bool = false) -> some View {
        modifier(OutlinedFieldModifier(label, isEmpty: isEmpty))
    }
}

// MARK: - Keep DSOutlinedField as a convenience wrapper for backward compat

/// Convenience wrapper view using the `.outlinedField()` modifier.
public struct DSOutlinedField<Content: View>: View {
    public var label: String
    public var isEmpty: Bool
    public var content: Content

    public init(_ label: String, isEmpty: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.isEmpty = isEmpty
        self.content = content()
    }

    public var body: some View {
        content.outlinedField(label, isEmpty: isEmpty)
    }
}

// MARK: - Border Shape

private struct FieldBorder: Shape {
    var labelWidth: CGFloat
    var labelOffset: CGFloat
    var cornerRadius: CGFloat = DS.Radius.small

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        let gapStart = labelOffset
        let gapEnd = labelOffset + labelWidth

        path.move(to: CGPoint(x: min(gapEnd, rect.maxX - r), y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: r), radius: r,
                     startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(center: CGPoint(x: r, y: r), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: max(gapStart, r), y: 0))

        return path
    }
}
