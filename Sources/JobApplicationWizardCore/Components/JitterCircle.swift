import SwiftUI

// MARK: - Jitter Circle (RGB/CMY Cuttlefish Blob)

/// Three overlapping circular fin instances with color mixing;
/// uses additive RGB in dark mode (overlap -> white) and
/// subtractive CMY in light mode.
public struct JitterCircle: View {
    @State private var startDate = Date()
    @Environment(\.colorScheme) private var colorScheme

    /// Size of the rendered canvas.
    var size: CGFloat = 48
    /// Mood controls animation amplitude presets.
    var mood: CuttleMood = .idle
    /// Direct amplitude override (takes precedence over mood when non-nil).
    var amplitudeFrac: Double? = nil

    private var effectiveAmplitude: Double {
        amplitudeFrac ?? mood.amplitudeFrac
    }

    private static let frequency: Double = 1.1
    private static let wavelength: Double = 0.46
    private static let waveSpeed: Double = -0.7
    private static let tailTaper: Double = 0.0
    private static let taperCurve: Double = 3.8

    private static let additiveInstances: [(rotation: Double, color: Color)] = [
        (0,              Color(red: 1, green: 0, blue: 0)),
        (2 * .pi / 3,   Color(red: 0, green: 1, blue: 0)),
        (4 * .pi / 3,   Color(red: 0, green: 0, blue: 1)),
    ]

    private static let subtractiveInstances: [(rotation: Double, color: Color)] = [
        (0,              .cmyCyan),
        (2 * .pi / 3,   .cmyMagenta),
        (4 * .pi / 3,   .cmyYellow),
    ]

    private var instances: [(rotation: Double, color: Color)] {
        colorScheme == .dark ? Self.additiveInstances : Self.subtractiveInstances
    }

    private var canvasBlendMode: GraphicsContext.BlendMode {
        colorScheme == .dark ? .plusLighter : .multiply
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            Canvas { context, canvasSize in
                let cx = canvasSize.width * 0.5
                let cy = canvasSize.height * 0.5
                let bodyRadius = Double(min(canvasSize.width, canvasSize.height)) * 0.38
                let amplitude = bodyRadius * effectiveAmplitude
                let totalSegments = 200
                let numWaves = max(1, (1.0 / Self.wavelength).rounded())
                let k = 2 * Double.pi * numWaves
                let omega = 2 * Double.pi * Self.frequency * Self.waveSpeed

                context.blendMode = canvasBlendMode

                for inst in instances {
                    var outerPoints: [CGPoint] = []
                    for i in 0..<totalSegments {
                        let t = Double(i) / Double(totalSegments)
                        let angle = inst.rotation - Double.pi / 2 + 2 * Double.pi * t

                        let ax = cx + bodyRadius * cos(angle)
                        let ay = cy + bodyRadius * sin(angle)
                        let nx = cos(angle)
                        let ny = sin(angle)

                        let wp = t <= 0.5 ? t * 2.0 : (1.0 - t) * 2.0
                        let taper = 1.0 - Self.tailTaper * pow(wp, Self.taperCurve)
                        let poleFade = sin(Double.pi * wp)
                        let wave = sin(k * wp - omega * elapsed)
                        let d = amplitude * taper * wave * poleFade
                        let baseW = amplitude * 0.6
                        let offset = baseW * taper * poleFade + d

                        outerPoints.append(CGPoint(
                            x: ax + offset * nx,
                            y: ay + offset * ny
                        ))
                    }

                    var outerPath = Path()
                    outerPath.move(to: outerPoints[0])
                    for j in 1..<outerPoints.count {
                        outerPath.addLine(to: outerPoints[j])
                    }
                    outerPath.closeSubpath()

                    context.fill(outerPath, with: .color(inst.color))
                }
            }
            .frame(width: size, height: size)
        }
        .drawingGroup()
    }

    public init(size: CGFloat = 48, mood: CuttleMood = .idle, amplitudeFrac: Double? = nil) {
        self.size = size
        self.mood = mood
        self.amplitudeFrac = amplitudeFrac
    }
}
