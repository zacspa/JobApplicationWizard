import WidgetKit
import SwiftUI
import JobApplicationShared

// MARK: - Timeline Provider

struct PipelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PipelineEntry {
        PipelineEntry(date: Date(), statusCounts: [:], nextInterview: nil, totalJobs: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PipelineEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PipelineEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> PipelineEntry {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.zsparks.JobApplicationWizard"
        )
        guard let url = containerURL?.appendingPathComponent("jobs.json"),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return PipelineEntry(date: Date(), statusCounts: [:], nextInterview: nil, totalJobs: 0)
        }

        var coordinatorError: NSError?
        var jobs: [JobApplication] = []
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordURL in
            if let data = try? Data(contentsOf: coordURL) {
                jobs = (try? JSONDecoder().decode([JobApplication].self, from: data)) ?? []
            }
        }
        guard coordinatorError == nil, !jobs.isEmpty || FileManager.default.fileExists(atPath: url.path) else {
            return PipelineEntry(date: Date(), statusCounts: [:], nextInterview: nil, totalJobs: 0)
        }

        var counts: [JobStatus: Int] = [:]
        for job in jobs {
            counts[job.status, default: 0] += 1
        }

        let now = Date()
        let nextInterview = jobs
            .flatMap { job in
                job.interviews
                    .filter { !$0.completed && ($0.date ?? .distantPast) > now }
                    .map { (job, $0) }
            }
            .min(by: { ($0.1.date ?? .distantFuture) < ($1.1.date ?? .distantFuture) })
            .map { InterviewInfo(company: $0.0.company, type: $0.1.type, date: $0.1.date ?? Date()) }

        return PipelineEntry(
            date: Date(),
            statusCounts: counts,
            nextInterview: nextInterview,
            totalJobs: jobs.count
        )
    }
}

// MARK: - Timeline Entry

struct PipelineEntry: TimelineEntry {
    let date: Date
    let statusCounts: [JobStatus: Int]
    let nextInterview: InterviewInfo?
    let totalJobs: Int
}

struct InterviewInfo {
    let company: String
    let type: String
    let date: Date
}

// MARK: - Small Widget View

struct PipelineWidgetSmallView: View {
    let entry: PipelineEntry

    var activeCount: Int {
        entry.statusCounts.filter { $0.key != .rejected && $0.key != .withdrawn }.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundStyle(.blue)
                Text("\(activeCount)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            Text("Active Jobs")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let interview = entry.nextInterview {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Interview")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(interview.company)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(interview.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct PipelineWidgetMediumView: View {
    let entry: PipelineEntry

    private let displayStatuses: [JobStatus] = [
        .wishlist, .applied, .phoneScreen, .interview, .offer
    ]

    var body: some View {
        HStack(spacing: 12) {
            // Status bar chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Pipeline")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(displayStatuses, id: \.self) { status in
                    let count = entry.statusCounts[status] ?? 0
                    HStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .font(.caption2)
                            .foregroundStyle(status.color)
                            .frame(width: 14)
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 20, alignment: .trailing)
                        GeometryReader { geo in
                            let maxCount = entry.statusCounts.values.max() ?? 1
                            let width = maxCount > 0
                                ? geo.size.width * CGFloat(count) / CGFloat(maxCount)
                                : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(status.color.opacity(0.6))
                                .frame(width: max(width, count > 0 ? 4 : 0))
                        }
                    }
                    .frame(height: 14)
                }
            }

            if let interview = entry.nextInterview {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Interview")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(interview.company)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(interview.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(interview.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Entry View

struct PipelineWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PipelineEntry

    var body: some View {
        switch family {
        case .systemMedium:
            PipelineWidgetMediumView(entry: entry)
        default:
            PipelineWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct PipelineWidget: Widget {
    let kind = "PipelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PipelineProvider()) { entry in
            PipelineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Job Pipeline")
        .description("Track your active job applications and upcoming interviews.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct JobWizardWidgets: WidgetBundle {
    var body: some Widget {
        PipelineWidget()
    }
}
