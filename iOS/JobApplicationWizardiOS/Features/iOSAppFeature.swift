import Foundation
import SwiftUI
import ComposableArchitecture
import JobApplicationShared
import UserNotifications

@Reducer
struct iOSAppFeature {
    @ObservableState
    struct State: Equatable {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        var settings: AppSettings = AppSettings()
        var searchQuery: String = ""
        var filterStatus: JobStatus? = nil
        var path = NavigationPath()
        var isLoading = true
        var importError: String? = nil
        var isSyncEnabled = false
        var isSyncing = false
        var lastSyncDate: Date? = nil
        var syncError: String? = nil
        var changeLog = ChangeLog()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case jobsLoaded([JobApplication])
        case settingsLoaded(AppSettings)
        case loadFailed
        case moveJob(UUID, JobStatus)
        case toggleFavorite(UUID)
        case addJob(JobApplication)
        case addNote(UUID, Note)
        case deleteJob(UUID)
        case searchQueryChanged(String)
        case filterStatusChanged(JobStatus?)
        case scheduleInterviewNotifications
        case importData(Data)
        case importCompleted(Result<AppDataExport, Error>)
        case exportRequested
        case dismissImportError
        // Sync
        case syncSignIn
        case syncAuthSucceeded
        case syncSignOut
        case syncNow
        case syncCompleted(Result<[ChangeEvent], Error>)
        case syncPushCompleted(Result<Void, Error>)
    }

    @Dependency(\.sharedPersistence) var persistence
    @Dependency(\.syncClient) var syncClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                if let log = try? ChangeLog.load(from: SharedPersistenceClient.changeLogURL) {
                    state.changeLog = log
                }
                return .run { send in
                    do {
                        let jobs = try await persistence.loadJobs()
                        await send(.jobsLoaded(jobs))
                    } catch {
                        await send(.loadFailed)
                    }
                    do {
                        let settings = try await persistence.loadSettings()
                        await send(.settingsLoaded(settings))
                    } catch {
                        // Use defaults if settings fail to load
                    }
                }

            case .jobsLoaded(let jobs):
                state.jobs = IdentifiedArray(uniqueElements: jobs)
                state.isLoading = false
                return .send(.scheduleInterviewNotifications)

            case .settingsLoaded(let settings):
                state.settings = settings
                return .none

            case .loadFailed:
                state.isLoading = false
                return .none

            case .moveJob(let id, let newStatus):
                state.jobs[id: id]?.status = newStatus
                let syncEffect = recordAndSync(.updateJobStatus(jobId: id, newStatus: newStatus), state: &state)
                return .merge(saveJobs(state.jobs), syncEffect)

            case .toggleFavorite(let id):
                state.jobs[id: id]?.isFavorite.toggle()
                let isFav = state.jobs[id: id]?.isFavorite ?? false
                let syncEffect = recordAndSync(.toggleFavorite(jobId: id, isFavorite: isFav), state: &state)
                return .merge(saveJobs(state.jobs), syncEffect)

            case .addJob(let job):
                state.jobs.append(job)
                let syncEffect = recordAndSync(.addJob(job), state: &state)
                return .merge(saveJobs(state.jobs), syncEffect)

            case .addNote(let jobId, let note):
                state.jobs[id: jobId]?.noteCards.append(note)
                let syncEffect = recordAndSync(.addNote(jobId: jobId, note: note), state: &state)
                return .merge(saveJobs(state.jobs), syncEffect)

            case .deleteJob(let id):
                state.jobs.remove(id: id)
                let syncEffect = recordAndSync(.deleteJob(jobId: id), state: &state)
                return .merge(saveJobs(state.jobs), syncEffect)

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .filterStatusChanged(let status):
                state.filterStatus = status
                return .none

            case .scheduleInterviewNotifications:
                let interviews = state.jobs.flatMap { job in
                    job.interviews
                        .filter { !$0.completed && $0.date != nil }
                        .map { (job, $0) }
                }
                return .run { _ in
                    await scheduleNotifications(for: interviews)
                }

            case .importData(let data):
                return .run { send in
                    do {
                        let export = try persistence.importAllData(data)
                        await send(.importCompleted(.success(export)))
                    } catch {
                        await send(.importCompleted(.failure(error)))
                    }
                }

            case .importCompleted(.success(let export)):
                state.jobs = IdentifiedArray(uniqueElements: export.jobs)
                state.settings = export.settings
                return saveJobs(state.jobs)

            case .importCompleted(.failure(let error)):
                state.importError = error.localizedDescription
                return .none

            case .exportRequested:
                return .none // Handled by the view via ShareLink

            case .dismissImportError:
                state.importError = nil
                return .none

            // MARK: - Sync Actions

            case .syncSignIn:
                return .run { send in
                    do {
                        try await syncClient.authenticate()
                        await send(.syncAuthSucceeded)
                    } catch {
                        await send(.syncCompleted(.failure(error)))
                    }
                }

            case .syncAuthSucceeded:
                state.isSyncEnabled = true
                return .send(.syncNow)

            case .syncSignOut:
                syncClient.signOut()
                state.isSyncEnabled = false
                state.lastSyncDate = nil
                return .none

            case .syncNow:
                state.isSyncing = true
                state.syncError = nil
                let unsyncedEvents = state.changeLog.unsyncedEvents
                let lastSync = state.changeLog.lastSyncTimestamp
                return .run { send in
                    // Push local events first
                    for event in unsyncedEvents {
                        try await syncClient.pushEvent(event)
                    }
                    // Then pull remote events
                    let remoteEvents = try await syncClient.pullEvents(lastSync)
                    await send(.syncCompleted(.success(remoteEvents)))
                } catch: { error, send in
                    await send(.syncCompleted(.failure(error)))
                }

            case .syncCompleted(.success(let remoteEvents)):
                state.isSyncing = false
                state.isSyncEnabled = true
                let now = Date()
                state.lastSyncDate = now
                state.changeLog.markSynced(through: now)
                state.changeLog.pruneSynced()
                // Apply remote events to local state
                if !remoteEvents.isEmpty {
                    ChangeLog.apply(events: remoteEvents, to: &state.jobs)
                    return .merge(saveJobs(state.jobs), saveChangeLog(state.changeLog))
                }
                return saveChangeLog(state.changeLog)

            case .syncCompleted(.failure(let error)):
                state.isSyncing = false
                state.syncError = error.localizedDescription
                return .none

            case .syncPushCompleted(.success):
                return .none

            case .syncPushCompleted(.failure(let error)):
                state.syncError = error.localizedDescription
                return .none
            }
        }
    }

    private func saveJobs(_ jobs: IdentifiedArrayOf<JobApplication>) -> Effect<Action> {
        .run { _ in
            try await persistence.saveJobs(Array(jobs))
        }
    }

    private func saveChangeLog(_ changeLog: ChangeLog) -> Effect<Action> {
        .run { _ in
            try? changeLog.save(to: SharedPersistenceClient.changeLogURL)
        }
    }

    /// Record a change event and push if sync is enabled.
    private func recordAndSync(
        _ action: ChangeAction,
        state: inout State
    ) -> Effect<Action> {
        guard state.isSyncEnabled else { return .none }
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let event = ChangeEvent(deviceId: deviceId, action: action)
        state.changeLog.append(event)
        let changeLog = state.changeLog
        return .run { [event] send in
            try? changeLog.save(to: SharedPersistenceClient.changeLogURL)
            do {
                try await syncClient.pushEvent(event)
                await send(.syncPushCompleted(.success(())))
            } catch {
                await send(.syncPushCompleted(.failure(error)))
            }
        }
    }
}

// MARK: - Filtered Jobs

extension iOSAppFeature.State {
    var filteredJobs: IdentifiedArrayOf<JobApplication> {
        var result = jobs
        if let filter = filterStatus {
            result = result.filter { $0.status == filter }
        }
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.company.lowercased().contains(query)
                || $0.title.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
            }
        }
        return result
    }
}

// MARK: - Interview Notifications

private func scheduleNotifications(
    for interviews: [(JobApplication, InterviewRound)]
) async {
    let center = UNUserNotificationCenter.current()
    let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    guard granted == true else { return }

    // Remove only interview notifications (prefixed with "interview-")
    let pending = await center.pendingNotificationRequests()
    let interviewIds = pending.filter { $0.identifier.hasPrefix("interview-") }.map(\.identifier)
    center.removePendingNotificationRequests(withIdentifiers: interviewIds)

    let now = Date()
    for (job, interview) in interviews {
        guard let interviewDate = interview.date, interviewDate > now else { continue }

        // 1 hour before
        let hourBefore = interviewDate.addingTimeInterval(-3600)
        if hourBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "Interview in 1 hour"
            content.body = "\(interview.type) with \(job.company)"
            if !interview.interviewers.isEmpty {
                content.body += " (\(interview.interviewers))"
            }
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: hourBefore.timeIntervalSince(now),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "interview-1h-\(interview.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        // 1 day before
        let dayBefore = interviewDate.addingTimeInterval(-86400)
        if dayBefore > now {
            let content = UNMutableNotificationContent()
            content.title = "Interview tomorrow"
            content.body = "\(interview.type) with \(job.company)"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: dayBefore.timeIntervalSince(now),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "interview-1d-\(interview.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
