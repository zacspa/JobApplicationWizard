import SwiftUI
import MarkdownUI
import AppKit

// MARK: - Chat Bubble

public struct ChatBubble: View {
    public let message: ChatMessage
    @State private var isHovered = false

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .assistant {
                bubbleContent
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                bubbleContent
            }
        }
    }

    @ViewBuilder
    var bubbleContent: some View {
        Group {
            if message.role == .assistant {
                Markdown(message.content)
                    .markdownTextStyle { FontSize(13) }
                    .textSelection(.enabled)
            } else {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
            .padding(.horizontal, message.role == .assistant ? 14 : 12).padding(.vertical, 8)
            .background(
                message.role == .user
                    ? Color.accentColor.opacity(0.15)
                    : Color(NSColor.controlBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) {
                if message.role == .assistant && isHovered {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.footnote)
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                    .offset(x: -6, y: -6)
                }
            }
            .onHover { isHovered = $0 }
    }
}

// MARK: - Suggestion Chip

public struct SuggestionChip: View {
    public let text: String
    public let action: () -> Void

    public init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

public struct FlowLayout: Layout {
    public var spacing: CGFloat = 8

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { y += rowHeight + spacing; x = 0; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += rowHeight + spacing; x = bounds.minX; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Chat Input Bar

public struct ChatInputBar: View {
    @Binding var input: String
    let isLoading: Bool
    let isReady: Bool
    let error: String?
    let onSend: () -> Void
    let onClear: () -> Void
    let hasMessages: Bool

    @FocusState private var inputFocused: Bool

    public init(
        input: Binding<String>,
        isLoading: Bool,
        isReady: Bool,
        error: String?,
        onSend: @escaping () -> Void,
        onClear: @escaping () -> Void,
        hasMessages: Bool
    ) {
        self._input = input
        self.isLoading = isLoading
        self.isReady = isReady
        self.error = error
        self.onSend = onSend
        self.onClear = onClear
        self.hasMessages = hasMessages
    }

    private var canSend: Bool {
        !isLoading && isReady
            && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let error {
                Text(error).font(.footnote).foregroundColor(.red)
                    .padding(8).background(Color.red.opacity(0.1)).cornerRadius(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Ask a follow-up...")
                            .foregroundColor(.secondary)
                            .font(.body)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $input)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .font(.body)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .frame(minHeight: 42, maxHeight: 100)
                        .focused($inputFocused)
                        .disabled(!isReady || isLoading)
                        .onKeyPress(keys: [.return]) { press in
                            if press.modifiers.contains(.shift) {
                                return .ignored
                            }
                            if canSend {
                                onSend()
                                Task { @MainActor in inputFocused = true }
                            }
                            return .handled
                        }
                }
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Button {
                    onSend()
                    Task { @MainActor in inputFocused = true }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(canSend ? .accentColor : .secondary)
                .disabled(!canSend)
            }
            .onAppear { inputFocused = true }
            HStack {
                Button("Clear conversation", action: onClear)
                    .buttonStyle(.plain).font(.footnote).foregroundColor(.secondary)
                    .disabled(!hasMessages)
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
