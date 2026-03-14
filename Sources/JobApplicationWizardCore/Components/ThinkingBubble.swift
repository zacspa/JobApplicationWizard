import SwiftUI

// MARK: - Color Mixing Helpers

extension Color {
    static let cmyCyan = Color(red: 0, green: 1, blue: 1)
    static let cmyMagenta = Color(red: 1, green: 0, blue: 1)
    static let cmyYellow = Color(red: 1, green: 1, blue: 0)
}

// MARK: - Color Mix Dot

/// A single "dot" composed of three overlapping circles that jitter randomly,
/// producing color mixing where they overlap. Uses additive RGB in dark mode
/// and subtractive CMY in light mode.
struct ColorMixDot: View {
    let seed: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var offsets: [CGSize] = Array(repeating: .zero, count: 3)

    private static let additiveColors: [Color] = [.red, .green, .blue]
    private static let subtractiveColors: [Color] = [.cmyCyan, .cmyMagenta, .cmyYellow]
    private let radius: CGFloat = 4
    private let jitterRange: CGFloat = 2.5

    private var colors: [Color] { colorScheme == .dark ? Self.additiveColors : Self.subtractiveColors }
    private var blendMode: BlendMode { colorScheme == .dark ? .plusLighter : .multiply }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(colors[i])
                    .frame(width: radius * 2, height: radius * 2)
                    .offset(offsets[i])
                    .blendMode(blendMode)
            }
        }
        .frame(width: radius * 2 + jitterRange * 2, height: radius * 2 + jitterRange * 2)
        .onAppear { jitter() }
    }

    private func jitter() {
        withAnimation(.easeInOut(duration: Double.random(in: 0.8...1.4)).repeatForever(autoreverses: true)) {
            offsets = (0..<3).map { _ in
                CGSize(
                    width: CGFloat.random(in: -jitterRange...jitterRange),
                    height: CGFloat.random(in: -jitterRange...jitterRange)
                )
            }
        }
    }
}

// MARK: - Wavy Rounded Rectangle

/// A rounded-rectangle border whose path physically undulates inward/outward
/// along its normal following a sine wave. Each point is manually computed by
/// walking the perimeter (straight edges + arc corners) so endpoints meet exactly.
struct WavyRoundedRect: Shape {
    var cornerRadius: CGFloat
    var amplitude: CGFloat
    var frequency: Double
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Inset the base rounded rect so outward wave peaks stay within the frame.
        let insetRect = rect.insetBy(dx: amplitude, dy: amplitude)
        guard insetRect.width > 0, insetRect.height > 0 else { return Path() }
        let r = min(cornerRadius, min(insetRect.width, insetRect.height) / 2)
        let steps = 256

        // Sample points and outward normals around the rounded rect perimeter.
        // Walk clockwise: top edge (left to right), top-right corner arc,
        // right edge (top to bottom), bottom-right arc, bottom edge (right to left),
        // bottom-left arc, left edge (bottom to top), top-left arc.
        struct Sample { var point: CGPoint; var normal: CGPoint }

        // Total perimeter for uniform parameterization
        let straightH = insetRect.width - 2 * r
        let straightV = insetRect.height - 2 * r
        let arcLen = 0.5 * .pi * r  // quarter circle
        let totalLen = 2 * straightH + 2 * straightV + 4 * arcLen

        func sampleAt(_ dist: CGFloat) -> Sample {
            var d = dist.truncatingRemainder(dividingBy: totalLen)
            if d < 0 { d += totalLen }

            // Segment 0: top edge, left to right
            let seg0 = straightH
            if d <= seg0 {
                let x = insetRect.minX + r + d
                return Sample(point: CGPoint(x: x, y: insetRect.minY), normal: CGPoint(x: 0, y: -1))
            }
            d -= seg0

            // Segment 1: top-right corner arc (center at maxX-r, minY+r)
            let seg1 = arcLen
            if d <= seg1 {
                let angle = -CGFloat.pi / 2 + (d / r) // from -π/2 to 0
                let cx = insetRect.maxX - r, cy = insetRect.minY + r
                return Sample(
                    point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                    normal: CGPoint(x: cos(angle), y: sin(angle))
                )
            }
            d -= seg1

            // Segment 2: right edge, top to bottom
            let seg2 = straightV
            if d <= seg2 {
                let y = insetRect.minY + r + d
                return Sample(point: CGPoint(x: insetRect.maxX, y: y), normal: CGPoint(x: 1, y: 0))
            }
            d -= seg2

            // Segment 3: bottom-right corner arc (center at maxX-r, maxY-r)
            let seg3 = arcLen
            if d <= seg3 {
                let angle = (d / r) // from 0 to π/2
                let cx = insetRect.maxX - r, cy = insetRect.maxY - r
                return Sample(
                    point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                    normal: CGPoint(x: cos(angle), y: sin(angle))
                )
            }
            d -= seg3

            // Segment 4: bottom edge, right to left
            let seg4 = straightH
            if d <= seg4 {
                let x = insetRect.maxX - r - d
                return Sample(point: CGPoint(x: x, y: insetRect.maxY), normal: CGPoint(x: 0, y: 1))
            }
            d -= seg4

            // Segment 5: bottom-left corner arc (center at minX+r, maxY-r)
            let seg5 = arcLen
            if d <= seg5 {
                let angle = CGFloat.pi / 2 + (d / r) // from π/2 to π
                let cx = insetRect.minX + r, cy = insetRect.maxY - r
                return Sample(
                    point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                    normal: CGPoint(x: cos(angle), y: sin(angle))
                )
            }
            d -= seg5

            // Segment 6: left edge, bottom to top
            let seg6 = straightV
            if d <= seg6 {
                let y = insetRect.maxY - r - d
                return Sample(point: CGPoint(x: insetRect.minX, y: y), normal: CGPoint(x: -1, y: 0))
            }
            d -= seg6

            // Segment 7: top-left corner arc (center at minX+r, minY+r)
            let angle = CGFloat.pi + (d / r) // from π to 3π/2
            let cx = insetRect.minX + r, cy = insetRect.minY + r
            return Sample(
                point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                normal: CGPoint(x: cos(angle), y: sin(angle))
            )
        }

        var path = Path()
        for i in 0..<steps {
            let frac = CGFloat(i) / CGFloat(steps)
            let dist = frac * totalLen
            let s = sampleAt(dist)
            let wave = CGFloat(sin(Double(frac) * .pi * 2.0 * frequency + phase)) * amplitude
            let pt = CGPoint(x: s.point.x + s.normal.x * wave, y: s.point.y + s.normal.y * wave)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Thinking Bubble

struct ThinkingBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    private let cr: CGFloat = 12
    private let waveAmplitude: CGFloat = 2.5

    private var borderColors: [Color] {
        colorScheme == .dark
            ? [.red, .green, .blue]
            : [.cmyCyan, .cmyMagenta, .cmyYellow]
    }
    private var borderBlend: BlendMode {
        colorScheme == .dark ? .plusLighter : .multiply
    }

    var body: some View {
        HStack(alignment: .top) {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let inset = waveAmplitude + 1
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        ColorMixDot(seed: i)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: cr))
                .padding(inset)
                .overlay(
                    WavyRoundedRect(cornerRadius: cr, amplitude: waveAmplitude, frequency: 3, phase: t * 2.2)
                        .stroke(borderColors[0], lineWidth: 1.8)
                        .blendMode(borderBlend)
                )
                .overlay(
                    WavyRoundedRect(cornerRadius: cr, amplitude: waveAmplitude, frequency: 5, phase: t * 1.7)
                        .stroke(borderColors[1], lineWidth: 1.8)
                        .blendMode(borderBlend)
                )
                .overlay(
                    WavyRoundedRect(cornerRadius: cr, amplitude: waveAmplitude, frequency: 7, phase: t * 3.1)
                        .stroke(borderColors[2], lineWidth: 1.8)
                        .blendMode(borderBlend)
                )
            }
            .drawingGroup()
            Spacer()
        }
    }
}
