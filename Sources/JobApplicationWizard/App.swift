import SwiftUI
import ComposableArchitecture

@main
struct JobApplicationWizardApp: App {
    @State var store = Store(initialState: AppFeature.State()) { AppFeature() }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
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
