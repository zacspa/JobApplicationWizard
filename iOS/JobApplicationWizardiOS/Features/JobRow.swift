import SwiftUI
import JobApplicationShared

struct JobRow: View {
    let job: JobApplication

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(job.displayTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if job.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(job.displayCompany)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !job.location.isEmpty {
                    Text(job.location)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !job.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(job.labels.prefix(2)) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.colorHex)?.opacity(0.2) ?? .gray.opacity(0.2))
                                .foregroundStyle(Color(hex: label.colorHex) ?? .gray)
                                .clipShape(Capsule())
                        }
                    }
                }

                Text(job.dateAdded.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
