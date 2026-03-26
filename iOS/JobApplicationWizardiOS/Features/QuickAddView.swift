import SwiftUI
import ComposableArchitecture
import JobApplicationShared

struct QuickAddView: View {
    let store: StoreOf<iOSAppFeature>

    @State private var company = ""
    @State private var title = ""
    @State private var url = ""
    @State private var location = ""
    @State private var salary = ""
    @State private var status: JobStatus = .wishlist
    @State private var selectedLabels: Set<UUID> = []
    @State private var showSavedConfirmation = false

    private let orderedStatuses: [JobStatus] = [
        .wishlist, .applied, .phoneScreen, .interview, .offer
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Job Info") {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                    TextField("Title", text: $title)
                        .textContentType(.jobTitle)
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Location", text: $location)
                        .textContentType(.addressCity)
                    TextField("Salary", text: $salary)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(orderedStatuses, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.icon)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Labels") {
                    FlowLayout(spacing: 8) {
                        ForEach(JobLabel.presets) { label in
                            Button {
                                if selectedLabels.contains(label.id) {
                                    selectedLabels.remove(label.id)
                                } else {
                                    selectedLabels.insert(label.id)
                                }
                            } label: {
                                Text(label.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedLabels.contains(label.id)
                                            ? (Color(hex: label.colorHex) ?? .gray)
                                            : (Color(hex: label.colorHex)?.opacity(0.15) ?? .gray.opacity(0.15))
                                    )
                                    .foregroundStyle(
                                        selectedLabels.contains(label.id)
                                            ? .white
                                            : (Color(hex: label.colorHex) ?? .gray)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Job")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveJob()
                    }
                    .disabled(company.isEmpty && title.isEmpty)
                }
            }
            .overlay {
                if showSavedConfirmation {
                    savedOverlay
                }
            }
        }
    }

    private func saveJob() {
        let labels = JobLabel.presets.filter { selectedLabels.contains($0.id) }
        var job = JobApplication()
        job.company = company
        job.title = title
        job.url = url
        job.status = status
        job.salary = salary
        job.location = location
        job.labels = labels
        store.send(.addJob(job))

        // Reset form
        company = ""
        title = ""
        url = ""
        location = ""
        salary = ""
        status = .wishlist
        selectedLabels = []

        // Show confirmation
        withAnimation {
            showSavedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedConfirmation = false
            }
        }
    }

    private var savedOverlay: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Job Saved")
                .font(.headline)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
    }
}
