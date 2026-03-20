import AppKit
import ComposableArchitecture
import Foundation

@Reducer
public struct CalendarFeature {
    private enum CancelID { case appDidBecomeActive, toastDismiss }

    @ObservableState
    public struct State: Equatable {
        public var accessGranted: Bool? = nil
        public var lastAccessCheck: Date? = nil
        public var showPicker: Bool = false
        public var pickerInterviewId: UUID? = nil
        public var pickerJobId: UUID? = nil
        public var events: [CalendarEvent] = []
        public var searchQuery: String = ""
        public var syncWarnings: [InterviewKey: CalendarSyncWarning] = [:]
        public var syncToast: String? = nil

        public init() {}
    }

    @CasePathable
    public enum Action: Equatable {
        // Picker
        case openPicker(jobId: UUID, interviewId: UUID)
        case dismissPicker
        case searchQueryChanged(String)
        case eventsLoaded([CalendarEvent])
        // Access
        case recheckAccess
        case accessResult(Bool)
        // Linking
        case eventSelected(CalendarEvent)
        case unlinkEvent(jobId: UUID, interviewId: UUID)
        // Sync
        case startListening
        case appDidBecomeActive
        case performSync(IdentifiedArrayOf<JobApplication>)
        case syncCompleted(updates: [CalendarSyncUpdate], missing: [CalendarSyncMissing])
        case dismissSyncToast
        // Warning
        case dismissWarning(InterviewKey)
        // Delegate
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case eventLinked(jobId: UUID, interviewId: UUID, event: CalendarEvent)
            case eventUnlinked(jobId: UUID, interviewId: UUID)
            case interviewDatesUpdated([CalendarSyncUpdate])
            case missingEventsDetected([CalendarSyncMissing])
            case needsJobsForSync
        }
    }

    @Dependency(\.calendarClient) var calendarClient
    @Dependency(\.date.now) var now
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .openPicker(let jobId, let interviewId):
                state.showPicker = true
                state.pickerInterviewId = interviewId
                state.pickerJobId = jobId

                let needsAccessCheck: Bool
                if let lastCheck = state.lastAccessCheck {
                    needsAccessCheck = now.timeIntervalSince(lastCheck) > 300
                } else {
                    needsAccessCheck = true
                }

                if needsAccessCheck {
                    return .merge(
                        .send(.recheckAccess),
                        fetchEvents()
                    )
                } else {
                    return fetchEvents()
                }

            case .dismissPicker:
                state.showPicker = false
                state.pickerInterviewId = nil
                state.pickerJobId = nil
                return .none

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .eventsLoaded(let events):
                state.events = events
                return .none

            case .recheckAccess:
                let status = calendarClient.authorizationStatus()
                if status == 3 || status == 4 {
                    state.accessGranted = true
                    state.lastAccessCheck = now
                    return .none
                } else if status == 0 {
                    return .run { send in
                        let granted = (try? await calendarClient.requestAccess()) ?? false
                        await send(.accessResult(granted))
                    }
                } else {
                    // denied or restricted
                    state.accessGranted = false
                    state.lastAccessCheck = now
                    return .none
                }

            case .accessResult(let granted):
                state.accessGranted = granted
                state.lastAccessCheck = now
                if granted {
                    return fetchEvents()
                }
                return .none

            case .eventSelected(let event):
                state.showPicker = false
                let jobId = state.pickerJobId
                let interviewId = state.pickerInterviewId
                state.pickerInterviewId = nil
                state.pickerJobId = nil
                guard let jobId, let interviewId else { return .none }
                return .send(.delegate(.eventLinked(jobId: jobId, interviewId: interviewId, event: event)))

            case .unlinkEvent(let jobId, let interviewId):
                let key = InterviewKey(jobId: jobId, interviewId: interviewId)
                state.syncWarnings.removeValue(forKey: key)
                return .send(.delegate(.eventUnlinked(jobId: jobId, interviewId: interviewId)))

            case .startListening:
                return .run { send in
                    for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                        await send(.appDidBecomeActive)
                    }
                }

            case .appDidBecomeActive:
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.delegate(.needsJobsForSync))
                }
                .cancellable(id: CancelID.appDidBecomeActive, cancelInFlight: true)

            case .performSync(let jobs):
                let linkedRounds = jobs.flatMap { job in
                    job.interviews
                        .filter { $0.calendarEventIdentifier != nil }
                        .map { (job: job, round: $0) }
                }
                guard !linkedRounds.isEmpty else { return .none }

                return .run { [linkedRounds, calendarClient] send in
                    var updates: [CalendarSyncUpdate] = []
                    var missing: [CalendarSyncMissing] = []

                    await withTaskGroup(of: (JobApplication, InterviewRound, CalendarEvent?).self) { group in
                        for (job, round) in linkedRounds {
                            group.addTask {
                                guard let identifier = round.calendarEventIdentifier else {
                                    return (job, round, nil)
                                }
                                let event = try? await calendarClient.fetchEvent(identifier)
                                return (job, round, event)
                            }
                        }
                        for await (job, round, event) in group {
                            if let event {
                                if let roundDate = round.date, abs(event.startDate.timeIntervalSince(roundDate)) > 60 {
                                    updates.append(CalendarSyncUpdate(
                                        jobId: job.id,
                                        interviewId: round.id,
                                        oldDate: round.date,
                                        newDate: event.startDate,
                                        jobCompany: job.displayCompany,
                                        roundNumber: round.round
                                    ))
                                }
                            } else {
                                // Fallback: title+date fuzzy match before marking missing
                                if let title = round.calendarEventTitle, let date = round.date {
                                    let interval = DateInterval(
                                        start: date.addingTimeInterval(-86400),
                                        end: date.addingTimeInterval(86400)
                                    )
                                    let nearbyEvents = (try? await calendarClient.fetchEvents(interval, nil)) ?? []
                                    let fuzzyMatch = nearbyEvents.first { evt in
                                        evt.title.localizedCaseInsensitiveContains(title) ||
                                        title.localizedCaseInsensitiveContains(evt.title)
                                    }
                                    if fuzzyMatch == nil {
                                        missing.append(CalendarSyncMissing(jobId: job.id, interviewId: round.id))
                                    }
                                } else {
                                    missing.append(CalendarSyncMissing(jobId: job.id, interviewId: round.id))
                                }
                            }
                        }
                    }
                    await send(.syncCompleted(updates: updates, missing: missing))
                }

            case .syncCompleted(let updates, let missing):
                // Store warnings for ALL missing events
                for miss in missing {
                    let key = InterviewKey(jobId: miss.jobId, interviewId: miss.interviewId)
                    state.syncWarnings[key] = .eventMissing
                }

                // Set toast
                if updates.count == 1 {
                    let update = updates[0]
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    state.syncToast = "Round \(update.roundNumber) for \(update.jobCompany) updated to \(formatter.string(from: update.newDate))"
                } else if updates.count > 1 {
                    state.syncToast = "\(updates.count) interview dates updated from Calendar"
                }

                var effects: [Effect<Action>] = []

                if !updates.isEmpty {
                    effects.append(.send(.delegate(.interviewDatesUpdated(updates))))
                }

                if !missing.isEmpty {
                    effects.append(.send(.delegate(.missingEventsDetected(missing))))
                }

                if state.syncToast != nil {
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: .seconds(4))
                            await send(.dismissSyncToast)
                        }
                        .cancellable(id: CancelID.toastDismiss, cancelInFlight: true)
                    )
                }

                if effects.isEmpty { return .none }
                return .merge(effects)

            case .dismissSyncToast:
                state.syncToast = nil
                return .none

            case .dismissWarning(let key):
                state.syncWarnings.removeValue(forKey: key)
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Helpers

    private func fetchEvents() -> Effect<Action> {
        .run { [calendarClient, now] send in
            let interval = DateInterval(start: now, duration: 30 * 24 * 60 * 60)
            let events = (try? await calendarClient.fetchEvents(interval, nil)) ?? []
            await send(.eventsLoaded(events))
        }
    }
}
