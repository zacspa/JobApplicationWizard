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
                    .font(DS.Typography.body)
                    .textSelection(.enabled)
            }
        }
            .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
            .background(
                message.role == .user
                    ? Color.accentColor.opacity(DS.Color.Opacity.tint)
                    : DS.Color.controlBackground
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.secondary.opacity(DS.Color.Opacity.tint), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(alignment: .bottomTrailing) {
                if message.role == .assistant && isHovered {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(DS.Typography.footnote)
                            .padding(DS.Spacing.xs)
                            .background(DS.Glass.chrome, in: RoundedRectangle(cornerRadius: DS.Radius.small))
                    }
                    .buttonStyle(GhostButtonStyle())
                    .offset(x: -DS.Spacing.xs, y: -DS.Spacing.xs)
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
        Button(text, action: action)
            .buttonStyle(PillButtonStyle())
    }
}

// MARK: - Flow Layout

public struct FlowLayout: Layout {
    public var spacing: CGFloat = DS.Spacing.sm

    public init(spacing: CGFloat = DS.Spacing.sm) {
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
        VStack(spacing: DS.Spacing.xs) {
            if let error {
                Text(error).font(DS.Typography.footnote).foregroundColor(DS.Color.error)
                    .padding(DS.Spacing.sm).background(DS.Color.error.opacity(DS.Color.Opacity.subtle)).cornerRadius(DS.Radius.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Ask a follow-up...")
                            .foregroundColor(DS.Color.textSecondary)
                            .font(DS.Typography.body)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.sm)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $input)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .font(DS.Typography.body)
                        .padding(.horizontal, DS.Spacing.xxs)
                        .padding(.vertical, DS.Spacing.xxs)
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
                .padding(.horizontal, DS.Spacing.xxs).padding(.vertical, DS.Spacing.xxxs)
                .background(DS.Color.textBackground)
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.small).stroke(DS.Color.border))
                Button {
                    onSend()
                    Task { @MainActor in inputFocused = true }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(canSend ? .accentColor : DS.Color.textSecondary)
                .disabled(!canSend)
            }
            .onAppear { inputFocused = true }
            HStack {
                Button("Clear conversation", action: onClear)
                    .buttonStyle(GhostButtonStyle()).font(DS.Typography.footnote)
                    .disabled(!hasMessages)
                Spacer()
            }
        }
        .padding(.horizontal, DS.Spacing.lg).padding(.vertical, DS.Spacing.md)
        .background(DS.Color.controlBackground)
    }
}
