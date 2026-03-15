import ComposableArchitecture
import Foundation

@Reducer
public struct HistoryFeature {

    @ObservableState
    public struct State: Equatable {
        public var showTimeline: Bool = false
        public var visibleEvents: [HistoryEvent] = []
        public var isTimeTraveling: Bool = false
        public var revertTargetId: UUID? = nil

        public init() {}
    }

    public enum Action {
        case toggleTimeline
        case eventsLoaded([HistoryEvent])
        case scrubTo(UUID)
        case confirmRevert
        case cancelTimeTraveling
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case applyCommands([HistoryCommand])
        }
    }

    @Dependency(\.historyClient) var historyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleTimeline:
                state.showTimeline.toggle()
                if state.showTimeline {
                    return .run { send in
                        let events = await historyClient.recentEvents(100)
                        await send(.eventsLoaded(events))
                    }
                } else {
                    state.isTimeTraveling = false
                    state.revertTargetId = nil
                }
                return .none

            case .eventsLoaded(let events):
                state.visibleEvents = events
                return .none

            case .scrubTo(let eventId):
                state.isTimeTraveling = true
                state.revertTargetId = eventId
                return .none

            case .confirmRevert:
                guard let targetId = state.revertTargetId else { return .none }
                state.isTimeTraveling = false
                state.revertTargetId = nil
                return .run { send in
                    let commands = try await historyClient.revertTo(targetId)
                    await send(.delegate(.applyCommands(commands)))
                }

            case .cancelTimeTraveling:
                state.isTimeTraveling = false
                state.revertTargetId = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
