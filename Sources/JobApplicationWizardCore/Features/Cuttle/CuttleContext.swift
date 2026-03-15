import SwiftUI

// MARK: - Cuttle Context

/// Determines what data Cuttle scopes its AI conversation to.
public enum CuttleContext: Equatable, Codable {
    case global
    case status(JobStatus)
    case job(UUID)

    public var label: String {
        switch self {
        case .global: return "All Jobs"
        case .status(let status): return status.rawValue
        case .job: return "Job"
        }
    }

    /// Returns a label that includes job count or job title info.
    public func displayLabel(jobs: [JobApplication]) -> String {
        switch self {
        case .global:
            return "All Jobs"
        case .status(let status):
            let count = jobs.filter { $0.status == status }.count
            return "\(status.rawValue) (\(count))"
        case .job(let id):
            if let job = jobs.first(where: { $0.id == id }) {
                return "\(job.displayCompany) \u{2014} \(job.displayTitle)"
            }
            return "Job"
        }
    }
}

// MARK: - Cuttle Mood

/// Controls JitterCircle animation presets.
public enum CuttleMood: Equatable {
    case idle
    case thinking
    case listening
    case transitioning

    public var amplitudeFrac: Double {
        switch self {
        case .idle:          return 0.08
        case .thinking:      return 0.12
        case .listening:     return 0.10
        case .transitioning: return 0.15
        }
    }
}

// MARK: - Drop Zone

/// A registered area in the window where Cuttle can be docked.
public struct DropZone: Equatable, Identifiable {
    public let id: String
    public var frame: CGRect
    public var context: CuttleContext

    public init(id: String, frame: CGRect, context: CuttleContext) {
        self.id = id
        self.frame = frame
        self.context = context
    }
}

// MARK: - Drop Zone Preference Key

/// Collects drop zone frames from views annotated with `.cuttleDockable()`.
public struct DropZonePreferenceKey: PreferenceKey {
    public static let defaultValue: [DropZone] = []

    public static func reduce(value: inout [DropZone], nextValue: () -> [DropZone]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Pending Context Environment Key

private struct CuttlePendingContextKey: EnvironmentKey {
    static let defaultValue: CuttleContext? = nil
}

public extension EnvironmentValues {
    var cuttlePendingContext: CuttleContext? {
        get { self[CuttlePendingContextKey.self] }
        set { self[CuttlePendingContextKey.self] = newValue }
    }
}

// MARK: - .cuttleDockable() View Modifier

public extension View {
    /// Makes this view a Cuttle drop target. Registers geometry as a DropZone
    /// and shows a glow overlay when Cuttle is hovering over it.
    func cuttleDockable(context: CuttleContext) -> some View {
        modifier(CuttleDockableModifier(context: context))
    }
}

struct CuttleDockableModifier: ViewModifier {
    let context: CuttleContext
    @Environment(\.cuttlePendingContext) private var pendingContext

    private var dropZoneId: String {
        switch context {
        case .global: return "global"
        case .status(let status): return "status-\(status.rawValue)"
        case .job(let id): return "job-\(id.uuidString)"
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("cuttle-window"))
                    Color.clear
                        .preference(
                            key: DropZonePreferenceKey.self,
                            value: [DropZone(id: dropZoneId, frame: frame, context: context)]
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(pendingContext == context ? 0.6 : 0)
                    .animation(.easeInOut(duration: 0.2), value: pendingContext)
            )
    }
}
