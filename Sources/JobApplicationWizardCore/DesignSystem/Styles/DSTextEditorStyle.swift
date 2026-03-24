import SwiftUI

/// An outlined TextEditor with a label on the top-leading border edge.
/// Matches the DSOutlinedField visual pattern.
public struct DSOutlinedTextEditor: View {
    public var label: String
    @Binding public var text: String
    public var minHeight: CGFloat

    @ScaledMetric private var labelPadding: CGFloat = 4

    public init(_ label: String, text: Binding<String>, minHeight: CGFloat = 60) {
        self.label = label
        self._text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Hidden Text that sizes to the content, driving the frame height
            Text(text.isEmpty ? " " : text)
                .font(DS.Typography.footnote)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: minHeight)
                .opacity(0)

            TextEditor(text: $text)
                .font(DS.Typography.footnote)
                .focusEffectDisabled()
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, -5)
                .padding(.top, -1)

            if text.isEmpty {
                Text(label)
                    .font(DS.Typography.footnote)
                    .foregroundColor(DS.Color.textSecondary)
                    .allowsHitTesting(false)
            }
        }
        .outlinedField(label, isEmpty: text.isEmpty)
    }
}

