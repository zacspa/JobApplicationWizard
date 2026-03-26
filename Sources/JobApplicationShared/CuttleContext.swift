import Foundation

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
