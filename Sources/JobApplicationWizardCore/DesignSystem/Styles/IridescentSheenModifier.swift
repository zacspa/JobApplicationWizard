import SwiftUI

public struct IridescentSheenModifier: ViewModifier {
    public var isActive: Bool
    public var cornerRadius: CGFloat

    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    public init(isActive: Bool = true, cornerRadius: CGFloat = DS.Radius.medium) {
        self.isActive = isActive
        self.cornerRadius = cornerRadius
    }

    private var sheenColors: [Color] {
        if colorScheme == .dark {
            return [
                .clear,
                .white.opacity(0.04),
                Color(hue: 0.55, saturation: 0.3, brightness: 1.0, opacity: 0.08),
                Color(hue: 0.75, saturation: 0.3, brightness: 1.0, opacity: 0.07),
                Color(hue: 0.85, saturation: 0.25, brightness: 1.0, opacity: 0.06),
                .white.opacity(0.04),
                .clear,
            ]
        } else {
            return [
                .clear,
                Color(hue: 0.55, saturation: 0.4, brightness: 0.9, opacity: 0.12),
                Color(hue: 0.65, saturation: 0.5, brightness: 0.85, opacity: 0.15),
                Color(hue: 0.8, saturation: 0.4, brightness: 0.9, opacity: 0.12),
                Color(hue: 0.9, saturation: 0.35, brightness: 0.85, opacity: 0.10),
                Color(hue: 0.55, saturation: 0.3, brightness: 0.9, opacity: 0.08),
                .clear,
            ]
        }
    }

    public func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let bandWidth: CGFloat = 100
                    let startOffset = -bandWidth - height
                    let endOffset = width + height
                    let offset = startOffset + phase * (endOffset - startOffset)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: sheenColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: bandWidth, height: sqrt(width * width + height * height) * 2.5)
                        .rotationEffect(.degrees(25))
                        .offset(x: offset, y: -height * 0.75)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .allowsHitTesting(false)
                .onAppear {
                    phase = 0
                    withAnimation(
                        .linear(duration: 4.0)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
                }
                .onDisappear { phase = 0 }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                phase = 0
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            } else {
                withAnimation(.linear(duration: 0.3)) { phase = 0 }
            }
        }
    }
}

extension View {
    /// Adds an animated iridescent sheen overlay.
    /// Intended for panels where Cuttle (AI assistant) is docked.
    public func iridescentSheen(
        isActive: Bool = true,
        cornerRadius: CGFloat = DS.Radius.medium
    ) -> some View {
        modifier(IridescentSheenModifier(isActive: isActive, cornerRadius: cornerRadius))
    }
}
