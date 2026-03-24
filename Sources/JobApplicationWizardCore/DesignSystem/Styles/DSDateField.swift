import SwiftUI

/// A date/time field that matches outlined field styling.
/// Shows formatted date when set, placeholder when nil. Taps to open a DatePicker popover.
public struct DSDateField: View {
    public var label: String
    @Binding public var date: Date?
    public var components: DatePicker.Components

    @State private var showPicker = false
    @State private var pickerDate = Date()

    public init(_ label: String, date: Binding<Date?>, components: DatePicker.Components = [.date, .hourAndMinute]) {
        self.label = label
        self._date = date
        self.components = components
    }

    private var displayText: String? {
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    public var body: some View {
        Button {
            pickerDate = date ?? Date()
            showPicker.toggle()
        } label: {
            HStack {
                if let displayText {
                    Text(displayText)
                        .font(DS.Typography.footnote)
                        .foregroundColor(DS.Color.textPrimary)
                } else {
                    Text("Set \(label.lowercased())...")
                        .font(DS.Typography.footnote)
                        .foregroundColor(DS.Color.textSecondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .outlinedField(label, isEmpty: date == nil)
        .popover(isPresented: $showPicker) {
            VStack {
                DatePicker("", selection: $pickerDate, displayedComponents: components)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .onChange(of: pickerDate) { _, newValue in
                        date = newValue
                    }
                HStack {
                    Button("Clear") {
                        date = nil
                        showPicker = false
                    }
                    .buttonStyle(GhostButtonStyle())
                    Spacer()
                    Button("Done") {
                        date = pickerDate
                        showPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(DS.Spacing.sm)
        }
    }
}
