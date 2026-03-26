import SwiftUI
import ComposableArchitecture

@main
struct JobApplicationWizardiOSApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State var store = Store(initialState: iOSAppFeature.State()) {
        iOSAppFeature()
    } withDependencies: {
        $0.syncClient = GoogleDriveSync.makeSyncClient()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .onChange(of: scenePhase) { _, newPhase in
                    store.send(.scenePhaseChanged(newPhase))
                }
        }
    }
}

struct RootView: View {
    @Bindable var store: StoreOf<iOSAppFeature>

    var body: some View {
        TabView {
            PipelineView(store: store)
                .tabItem { Label("Pipeline", systemImage: "list.bullet") }
            QuickAddView(store: store)
                .tabItem { Label("Add Job", systemImage: "plus.circle") }
            SettingsViewiOS(store: store)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .task {
            store.send(.onAppear)
        }
    }
}
