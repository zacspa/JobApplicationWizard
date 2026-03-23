import SwiftUI
import AppKit

// MARK: - Custom NSTextField subclass

private class TransparentTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.drawsBackground = false
            editor.backgroundColor = .clear
            editor.insertionPointColor = .controlAccentColor
            editor.enclosingScrollView?.verticalScrollElasticity = .none
            editor.enclosingScrollView?.horizontalScrollElasticity = .none
        }
        return result
    }
}

// MARK: - SwiftUI wrapper

/// An AppKit-backed text field with no focus ring, no background, no bezel,
/// and a transparent field editor. Designed to work with `.outlinedField()`.
/// Supports an optional `onSubmit` closure for Return key handling.
public struct DSTextField: NSViewRepresentable {
    public var placeholder: String
    @Binding public var text: String
    public var font: NSFont
    public var onSubmit: (() -> Void)?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        font: NSFont = .systemFont(ofSize: NSFont.smallSystemFontSize),
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.font = font
        self.onSubmit = onSubmit
    }

    public func makeNSView(context: Context) -> NSTextField {
        let field = TransparentTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.backgroundColor = .clear
        field.font = font
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentHuggingPriority(.init(1), for: .horizontal)
        field.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    public func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.font = font
        context.coordinator.onSubmit = onSubmit

        if let superview = field.superview {
            field.frame = superview.bounds
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField,
                  let textMovement = obj.userInfo?["NSTextMovement"] as? Int,
                  textMovement == NSReturnTextMovement else { return }
            text.wrappedValue = field.stringValue
            onSubmit?()
        }
    }
}
