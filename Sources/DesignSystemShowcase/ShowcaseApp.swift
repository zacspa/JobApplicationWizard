import AppKit
import SwiftUI
import JobApplicationWizardCore

class ShowcaseAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct DesignSystemShowcaseApp: App {
    @NSApplicationDelegateAdaptor(ShowcaseAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Design System Showcase") {
            ShowcaseRootView()
        }
        .defaultSize(width: 1000, height: 800)
    }
}

struct ShowcaseRootView: View {
    @State private var selectedSection: ShowcaseSection = .colors

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(ShowcaseSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            ScrollView {
                selectedSection.view
                    .padding(DS.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.windowBackground)
        }
    }
}

// MARK: - Sections

enum ShowcaseSection: String, CaseIterable, Identifiable {
    case colors
    case typography
    case spacing
    case radii
    case shadows
    case glass
    case buttons
    case cards
    case inputs
    case noteCards
    case rows
    case sheen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colors: return "Colors"
        case .typography: return "Typography"
        case .spacing: return "Spacing"
        case .radii: return "Corner Radii"
        case .shadows: return "Shadows"
        case .glass: return "Glass Surfaces"
        case .buttons: return "Buttons"
        case .cards: return "Cards"
        case .inputs: return "Inputs"
        case .noteCards: return "Note Cards"
        case .rows: return "Rows & Bars"
        case .sheen: return "Iridescent Sheen"
        }
    }

    var icon: String {
        switch self {
        case .colors: return "paintpalette"
        case .typography: return "textformat"
        case .spacing: return "ruler"
        case .radii: return "square.on.square"
        case .shadows: return "shadow"
        case .glass: return "rectangle.on.rectangle"
        case .buttons: return "button.horizontal"
        case .cards: return "rectangle.portrait"
        case .inputs: return "text.cursor"
        case .noteCards: return "note.text"
        case .rows: return "list.bullet"
        case .sheen: return "sparkles"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .colors: ColorsShowcase()
        case .typography: TypographyShowcase()
        case .spacing: SpacingShowcase()
        case .radii: RadiiShowcase()
        case .shadows: ShadowsShowcase()
        case .glass: GlassShowcase()
        case .buttons: ButtonsShowcase()
        case .cards: CardsShowcase()
        case .inputs: InputsShowcase()
        case .noteCards: NoteCardsShowcase()
        case .rows: RowsShowcase()
        case .sheen: SheenShowcase()
        }
    }
}
