#if os(macOS)
import AppKit
#endif
import SwiftUI
import ComposableArchitecture
import Sparkle
import JobApplicationWizardCore

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy and bring window to front
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
#endif

@main
struct JobApplicationWizardApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    @State var store = Store(initialState: AppFeature.State()) { AppFeature() }
    private let updaterController: SPUStandardUpdaterController

    init() {
        #if DEBUG
        let startUpdater = false
        #else
        let startUpdater = true
        #endif
        updaterController = SPUStandardUpdaterController(
            startingUpdater: startUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(store: store)
                .frame(minWidth: 960, minHeight: 600)
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
            #if DEBUG
            DebugMenuCommands()
            #endif
        }

        Window("New Job Application", id: "add-job") {
            AddJobView(store: store.scope(state: \.addJob, action: \.addJob))
                .onChange(of: store.addJob.canSave) { _, _ in }  // keep store alive
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 700)

        #if DEBUG
        Window("Debug", id: "debug") {
            DebugPanel(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 400)
        #endif

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
