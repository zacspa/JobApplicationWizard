import SwiftUI
import ComposableArchitecture
import Sparkle

@main
struct JobApplicationWizardApp: App {
    @State var store = Store(initialState: AppFeature.State()) { AppFeature() }
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .help) {
                Link("Claude API Documentation",
                     destination: URL(string: "https://docs.anthropic.com")!)
            }
        }

        Window("New Job Application", id: "add-job") {
            AddJobView(store: store.scope(state: \.addJob, action: \.addJob))
                .onChange(of: store.addJob.canSave) { _, _ in }  // keep store alive
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 700)

        Settings {
            SettingsView(store: store)
                .frame(width: 480)
        }
    }
}

struct CheckForUpdatesView: View {
    let updater: SPUUpdater
    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
    }
}
