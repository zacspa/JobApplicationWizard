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

// MARK: - Perimeter Sampler

/// A point and its outward-facing unit normal on a shape's perimeter.
struct PerimeterSample {
    var point: CGPoint
    var normal: CGPoint
}

/// Produces evenly-spaced (point, normal) samples around a closed perimeter.
/// `fraction` runs from 0 (start) to 1 (back to start).
protocol PerimeterSampler {
    func sample(at fraction: CGFloat, in rect: CGRect) -> PerimeterSample
}

// MARK: - Wavy Shape (generic)

/// A `Shape` that displaces a base perimeter outward/inward with a sine wave.
/// The perimeter geometry is provided by any `PerimeterSampler`.
///
/// Each bump's displacement is modulated by a second, slower sine wave driven by `time`,
/// so bumps independently breathe in and out rather than rigidly rotating.
struct WavyShape<Sampler: PerimeterSampler & Sendable>: Shape {
    var sampler: Sampler
    var amplitude: CGFloat
    var frequency: Double
    var phase: Double
    /// Continuous clock time for per-bump amplitude modulation. When 0, falls back to
    /// the original rotate-only behavior (used by ThinkingBubble's existing animations).
    var time: Double = 0

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let steps = 256
        var path = Path()
        for i in 0..<steps {
            let frac = CGFloat(i) / CGFloat(steps)
            let s = sampler.sample(at: frac, in: rect)
            // Base spatial wave: N bumps around the perimeter
            let spatial = sin(Double(frac) * .pi * 2.0 * frequency + phase)
            // Per-bump temporal modulation: each bump breathes at its own rate
            let modulation: Double
            if time != 0 {
                // Use the bump's angular position as a seed for its breathing rate
                let bumpAngle = Double(frac) * .pi * 2.0 * frequency
                modulation = 0.5 + 0.5 * sin(time * 1.3 + bumpAngle * 0.7)
            } else {
                modulation = 1.0
            }
            let wave = CGFloat(spatial * modulation) * amplitude
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

// MARK: - Rounded Rect Sampler

struct RoundedRectSampler: PerimeterSampler {
    var cornerRadius: CGFloat
    var amplitude: CGFloat

    func sample(at fraction: CGFloat, in rect: CGRect) -> PerimeterSample {
        let insetRect = rect.insetBy(dx: amplitude, dy: amplitude)
        guard insetRect.width > 0, insetRect.height > 0 else {
            return PerimeterSample(point: .zero, normal: CGPoint(x: 0, y: -1))
        }
        let r = min(cornerRadius, min(insetRect.width, insetRect.height) / 2)

        let straightH = insetRect.width - 2 * r
        let straightV = insetRect.height - 2 * r
        let arcLen = 0.5 * .pi * r
        let totalLen = 2 * straightH + 2 * straightV + 4 * arcLen

        var d = (fraction * totalLen).truncatingRemainder(dividingBy: totalLen)
        if d < 0 { d += totalLen }

        // Segment 0: top edge, left to right
        if d <= straightH {
            let x = insetRect.minX + r + d
            return PerimeterSample(point: CGPoint(x: x, y: insetRect.minY), normal: CGPoint(x: 0, y: -1))
        }
        d -= straightH

        // Segment 1: top-right corner arc
        if d <= arcLen {
            let angle = -CGFloat.pi / 2 + (d / r)
            let cx = insetRect.maxX - r, cy = insetRect.minY + r
            return PerimeterSample(
                point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                normal: CGPoint(x: cos(angle), y: sin(angle))
            )
        }
        d -= arcLen

        // Segment 2: right edge, top to bottom
        if d <= straightV {
            let y = insetRect.minY + r + d
            return PerimeterSample(point: CGPoint(x: insetRect.maxX, y: y), normal: CGPoint(x: 1, y: 0))
        }
        d -= straightV

        // Segment 3: bottom-right corner arc
        if d <= arcLen {
            let angle = d / r
            let cx = insetRect.maxX - r, cy = insetRect.maxY - r
            return PerimeterSample(
                point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                normal: CGPoint(x: cos(angle), y: sin(angle))
            )
        }
        d -= arcLen

        // Segment 4: bottom edge, right to left
        if d <= straightH {
            let x = insetRect.maxX - r - d
            return PerimeterSample(point: CGPoint(x: x, y: insetRect.maxY), normal: CGPoint(x: 0, y: 1))
        }
        d -= straightH

        // Segment 5: bottom-left corner arc
        if d <= arcLen {
            let angle = CGFloat.pi / 2 + (d / r)
            let cx = insetRect.minX + r, cy = insetRect.maxY - r
            return PerimeterSample(
                point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
                normal: CGPoint(x: cos(angle), y: sin(angle))
            )
        }
        d -= arcLen

        // Segment 6: left edge, bottom to top
        if d <= straightV {
            let y = insetRect.maxY - r - d
            return PerimeterSample(point: CGPoint(x: insetRect.minX, y: y), normal: CGPoint(x: -1, y: 0))
        }
        d -= straightV

        // Segment 7: top-left corner arc
        let angle = CGFloat.pi + (d / r)
        let cx = insetRect.minX + r, cy = insetRect.minY + r
        return PerimeterSample(
            point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
            normal: CGPoint(x: cos(angle), y: sin(angle))
        )
    }
}

// MARK: - Circle Sampler

struct CircleSampler: PerimeterSampler {
    var amplitude: CGFloat

    func sample(at fraction: CGFloat, in rect: CGRect) -> PerimeterSample {
        let insetRect = rect.insetBy(dx: amplitude, dy: amplitude)
        guard insetRect.width > 0, insetRect.height > 0 else {
            return PerimeterSample(point: .zero, normal: CGPoint(x: 0, y: -1))
        }
        let r = min(insetRect.width, insetRect.height) / 2
        let cx = insetRect.midX
        let cy = insetRect.midY
        let angle = fraction * 2 * .pi
        return PerimeterSample(
            point: CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle)),
            normal: CGPoint(x: cos(angle), y: sin(angle))
        )
    }
}

// MARK: - Convenience Type Aliases

/// Wavy rounded rectangle (drop-in replacement for the old `WavyRoundedRect`).
typealias WavyRoundedRect = WavyShape<RoundedRectSampler>

extension WavyRoundedRect {
    init(cornerRadius: CGFloat, amplitude: CGFloat, frequency: Double, phase: Double) {
        self.init(
            sampler: RoundedRectSampler(cornerRadius: cornerRadius, amplitude: amplitude),
            amplitude: amplitude, frequency: frequency, phase: phase
        )
    }
}

/// Wavy circle border.
typealias WavyCircle = WavyShape<CircleSampler>

extension WavyCircle {
    init(amplitude: CGFloat, frequency: Double, phase: Double, time: Double = 0) {
        self.init(
            sampler: CircleSampler(amplitude: amplitude),
            amplitude: amplitude, frequency: frequency, phase: phase, time: time
        )
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
