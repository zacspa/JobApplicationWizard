# iOS Companion App Plan

## Context

The desktop Job Application Wizard is a macOS-only SwiftUI/TCA app. A React Native companion was scaffolded but two adversarial reviews revealed fundamental issues: date epoch mismatches, enum value drift, no shared schema, and hollow Android value. Building a native SwiftUI iOS app lets us share models and persistence directly.

A second swarm review of the initial iOS plan caught critical build system issues and challenged the "miniature desktop port" scope. The revised plan addresses those findings and shifts v1 toward mobile-native features: a widget, interview notifications, and a share extension.

## Architecture

### Build System: Xcode Project + SPM Package (not SPM executable)

The swarm review confirmed that SPM `.executableTarget` cannot produce an iOS `.app` bundle (no Info.plist, asset catalog, entitlements, provisioning). The iOS app needs a proper Xcode project.

```
JobApplicationWizard/
  Package.swift                      (shared SPM package)
    +-- JobApplicationShared         (models, persistence interface, shared enums)
    +-- JobApplicationWizardCore     (macOS views, AppKit deps, Sparkle, ACP, MarkdownUI)
    +-- JobApplicationWizard         (macOS executable, unchanged)
    +-- DesignSystemShowcase         (unchanged)
    +-- Tests                        (unchanged)
  iOS/
    JobApplicationWizardiOS.xcodeproj
      +-- App target                 (depends on JobApplicationShared via local SPM)
      +-- WidgetExtension target     (pipeline counts, next interview)
      +-- ShareExtension target      (capture job URLs from Safari/LinkedIn)
```

### Platform-Conditional Dependencies (Sparkle/ACP fix)

Sparkle is a macOS-only XCFramework. Adding `.iOS(.v17)` to Package.swift platforms causes SPM to fail resolving it for iOS. Fix with conditional dependencies:

```swift
platforms: [.macOS(.v14), .iOS(.v17)],

.target(
    name: "JobApplicationWizardCore",
    dependencies: [
        "JobApplicationShared",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS])),
        .product(name: "ACP", package: "swift-sdk", condition: .when(platforms: [.macOS])),
        .product(name: "ACPModel", package: "swift-sdk", condition: .when(platforms: [.macOS])),
        .product(name: "MarkdownUI", package: "swift-markdown-ui", condition: .when(platforms: [.macOS])),
    ],
),
```

Every `import Sparkle`, `import ACP`, `import MarkdownUI` in `JobApplicationWizardCore` must be wrapped in `#if canImport(Sparkle)` / `#if os(macOS)` guards.

---

## Phase 1: Extract `JobApplicationShared` Target

**Goal:** Create the shared target; macOS app continues to build and pass tests. Keep this minimal to avoid destabilizing before the v3.1.0 public launch (2026-03-30).

### 1.1 Create `Sources/JobApplicationShared/`

Move or extract these files (all platform-agnostic):

| File to move | From | Notes |
|---|---|---|
| `Models.swift` | `JobApplicationWizardCore/` | Wrap `NSColor` on line 530: full `#if os(macOS)` / `#else` with `UIColor.getRed(&r, &g, &b, alpha:)` (different API shape, not a drop-in swap) |
| `CuttleContext` enum ONLY | `Features/Cuttle/CuttleContext.swift` | Extract just the `CuttleContext` enum (~10 lines) to a new file. The rest of that file (160+ lines: `CuttleDockableModifier`, `DropZone`, `DropZonePreferenceKey`, `.iridescentSheen`) stays in `JobApplicationWizardCore`. |
| `AgentActionMode` enum ONLY | `Features/Cuttle/AgentActionParser.swift:191-194` | Extract to new file `AgentActionMode.swift` (4 lines) |

Extract enums from files that have macOS dependencies (create new files in shared target):

| Enum | Currently in | Why shared |
|---|---|---|
| `ViewMode` | `AppFeature.swift:5` | Used by `AppSettings`. Remove from AppFeature.swift; add `import JobApplicationShared` there. |
| `AIProvider` | `Models.swift:413` | Already in Models.swift, moves with it |
| `DocumentType` | `DocumentClient.swift:8` | Used by `JobDocument` in Models. Extract enum only; `DocumentClient` itself (with `import PDFKit`/`AppKit`) stays in macOS target. |
| `ATSProvider` | `JobURLClient.swift:6` | Used by `JobApplication` |

### 1.2 Create shared `PersistenceClient` interface

New file: `Sources/JobApplicationShared/SharedPersistenceClient.swift`

Single persistence interface used by both platforms:

```swift
public struct SharedPersistenceClient {
    public var loadJobs: @Sendable () async throws -> [JobApplication]
    public var saveJobs: @Sendable ([JobApplication]) async throws -> Void
    public var loadSettings: @Sendable () async throws -> AppSettings
    public var saveSettings: @Sendable (AppSettings) async throws -> Void
    public var exportAllData: @Sendable ([JobApplication], AppSettings) -> Data
    public var importAllData: @Sendable (Data) throws -> AppDataExport
}
```

The macOS `PersistenceClient` extends this with CSV, save/open panels. Both platform targets provide their own `liveValue`.

### 1.3 Update `Package.swift`

Add `JobApplicationShared` target (see architecture section above for conditional deps).

Use explicit `import JobApplicationShared` in files that need it, NOT `@_exported import`. The `@_exported` attribute is unofficial/underscored and could break on future Swift compiler updates. Adding explicit imports is more work but stable.

### 1.4 Verify

- `swift build` succeeds for macOS targets
- `swift build` for iOS destination also succeeds: `swift build --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"` (verifies shared target compiles for iOS; `swift build` alone only exercises macOS)
- Existing tests pass
- No `import AppKit`, no `NS*` types, no `#if os(macOS)` without matching `#else` in `JobApplicationShared/`

---

## Phase 2: iOS Xcode Project + Core Features

**Goal:** Buildable iOS app with mobile-native features, local persistence only (no sync yet).

### 2.1 Create `iOS/` directory with Xcode project

```
iOS/
  JobApplicationWizardiOS.xcodeproj
  JobApplicationWizardiOS/
    App.swift
    Info.plist
    Assets.xcassets/          (app icon, accent color)
    Entitlements.entitlements
    Features/
      iOSAppFeature.swift     (slim TCA reducer)
      PipelineView.swift      (grouped list by status)
      JobRow.swift
      JobDetailViewiOS.swift  (read + quick-edit)
      QuickAddView.swift      (minimal form)
      SettingsViewiOS.swift   (profile, import/export)
      StatusPicker.swift
    Persistence/
      iOSPersistenceClient.swift
  WidgetExtension/
    PipelineWidget.swift      (job counts by status, next interview)
    Info.plist
    Assets.xcassets/
  ShareExtension/
    ShareViewController.swift (capture URL -> create wishlist job)
    Info.plist
```

The Xcode project adds `JobApplicationShared` as a local SPM package dependency.

### 2.2 v1 Feature Set (mobile-native, not a desktop port)

**Feature 1: Pipeline Widget**
- Small widget: total active job count + next interview date/company
- Medium widget: bar showing count per status (Wishlist, Applied, Phone Screen, Interview, Offer)
- Uses `WidgetKit` + `TimelineProvider` reading from shared `jobs.json`
- App group container for shared data between app and widget extension

**Feature 2: Interview Reminder Notifications**
- On app launch and when jobs change, scan `InterviewRound.date` for upcoming interviews
- Schedule `UNNotificationRequest` local notifications (e.g., 1 hour before, 1 day before)
- Tapping notification deep-links to the job detail view
- Uses existing `InterviewRound` model (already has `date`, `type`, `interviewers` fields)

**Feature 3: Share Extension (Quick Capture)**
- Share a URL from Safari/LinkedIn/email into the app
- Creates a `JobApplication` in `wishlist` status with the URL populated
- Minimal UI: just company name + title fields, pre-filled if possible via URL parsing
- Writes to the shared app group container; main app picks up on next launch

**Feature 4: Core App (list + detail + add + settings)**
- Pipeline list grouped by `JobStatus` sections with count badges and status icons
- Job detail: read-only display with quick-edit (status picker, favorite toggle, add note)
- Quick-add form: company, title, URL, status, labels
- Settings: profile display, JSON export via `ShareLink`, import via document picker

### 2.3 `iOSAppFeature` reducer

```swift
@Reducer
struct iOSAppFeature {
    @ObservableState
    struct State: Equatable {
        var jobs: IdentifiedArrayOf<JobApplication> = []
        var settings: AppSettings = AppSettings()
        var searchQuery: String = ""
        var filterStatus: JobStatus? = nil
        var path = NavigationPath()
    }

    enum Action {
        case onAppear
        case jobsLoaded([JobApplication])
        case settingsLoaded(AppSettings)
        case moveJob(UUID, JobStatus)
        case toggleFavorite(UUID)
        case addJob(JobApplication)
        case addNote(UUID, Note)
        case searchQueryChanged(String)
        case filterStatusChanged(JobStatus?)
        case scheduleInterviewNotifications
        case importData(Data)
        case exportRequested
    }
}
```

### 2.4 Navigation

```
TabView
  Tab 1: Pipeline (NavigationStack)
    -> PipelineView (List grouped by JobStatus sections)
       -> JobDetailViewiOS (read + quick-edit)
  Tab 2: Add Job
    -> QuickAddView (form, dismisses to Pipeline on save)
  Tab 3: Settings
    -> SettingsViewiOS (profile, import/export)
```

### 2.5 iOS persistence (local)

Same JSON file format as macOS, stored in app group container (shared with widget + share extension):
`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.zsparks.JobApplicationWizard")`

Identical `JSONEncoder`/`JSONDecoder` (default date strategy = Apple reference date). Shared models guarantee identical encoding.

### 2.6 Design System

Move platform-agnostic DS tokens to `JobApplicationShared`:
- `DSSpacing.swift`, `DSRadius.swift` (CGFloat constants)
- `DSShadow.swift`, `DSAccent.swift`, `DSMaterial.swift` (pure SwiftUI)

**DSTypography note:** Hardcoded point sizes (60pt `displayLarge`, 9pt `micro`) do not participate in Dynamic Type on iOS. For the iOS app, use semantic SwiftUI font styles (`.title`, `.body`, `.caption2`) instead of the DS typography tokens. Only adopt DS typography tokens that use relative sizes.

Platform-specific:
- `DSColor.swift` (uses `NSColor.windowBackgroundColor`): iOS app uses `UIColor.systemBackground` equivalents
- `DSTextField.swift` (is `NSViewRepresentable`): iOS uses native SwiftUI `TextField`

---

## Phase 3: Google Drive Sync with Change Log

**Goal:** Sync between macOS and iOS via Google Drive, using an append-only change log to avoid monolithic file replacement and data loss.

### 3.1 Why Google Drive (not iCloud)

- User preference; works across ecosystem boundaries
- No Apple entitlements or provisioning changes needed
- Google Drive REST API is well-documented
- App-scoped folder via Google Drive API (no broad file access needed)

### 3.2 Change log architecture (event sourcing)

Instead of syncing a monolithic `jobs.json` (which causes last-writer-wins data loss), use an append-only change log:

```
Google Drive: /JobApplicationWizard/
  state.json          (full snapshot, periodically compacted)
  changelog/
    000001.json       (change event)
    000002.json
    ...
```

Each change event is a small JSON file:

```swift
public struct ChangeEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let deviceId: String
    public let action: ChangeAction
}

public enum ChangeAction: Codable {
    case addJob(JobApplication)
    case updateJobStatus(jobId: UUID, newStatus: JobStatus)
    case toggleFavorite(jobId: UUID)
    case addNote(jobId: UUID, note: Note)
    case deleteJob(jobId: UUID)
    case updateSettings(AppSettings)
    // ... other granular actions
}
```

**Sync flow:**
1. On save, append a `ChangeEvent` to the local log and upload it to Google Drive `changelog/`
2. On launch / periodically, fetch new change events from Google Drive since last sync
3. Apply events in timestamp order to rebuild state
4. Periodically compact: write a full `state.json` snapshot, prune old changelog entries

**Benefits over monolithic sync:**
- No data loss: concurrent edits on different jobs produce separate events that merge cleanly
- Small uploads: each event is a few KB, not the entire database
- Conflict-free for non-overlapping edits (most common case)
- Same-field conflicts can be resolved by timestamp ordering

### 3.3 `SyncClient` dependency

```swift
public struct SyncClient {
    public var authenticate: @Sendable () async throws -> Void
    public var pushChange: @Sendable (ChangeEvent) async throws -> Void
    public var pullChanges: @Sendable (since: Date?) async throws -> [ChangeEvent]
    public var pushSnapshot: @Sendable (Data) async throws -> Void
    public var pullSnapshot: @Sendable () async throws -> Data?
}
```

### 3.4 Google Drive integration

- Use Google Sign-In SDK for iOS authentication
- Use Google Drive REST API v3 (app data folder scope: `drive.appdata`)
- macOS: use OAuth via browser redirect for Google Sign-In
- Both platforms store refresh token in Keychain

### 3.5 Bulk field exclusion from sync

To keep change events small, exclude bulk fields from granular sync:
- `chatHistory` (unbounded, AI-generated, macOS-only feature)
- `documents[].rawText` (full document text)
- `jobDescription` and `coverLetter` (large text blobs)

These sync only in periodic full snapshots (`state.json`), not in individual change events. This keeps per-event uploads to a few KB.

---

## Scope Boundaries

**v1 includes:**
- Pipeline widget (small + medium sizes)
- Interview reminder notifications
- Share extension for quick URL capture
- Pipeline list view (grouped by status)
- Job detail (read-only with quick-edit: status, favorite, notes)
- Quick-add job form
- Settings: profile display, JSON import/export
- Google Drive sync with change log

**v1 does NOT include:**
- Kanban board (horizontal columns don't work on phone)
- AI/Cuttle integration (deferred; ACP requires subprocesses which iOS prohibits, Claude API requires separate billing; future option is proxying through Mac over local network)
- Document management
- Calendar integration
- Full inline editing of all fields
- Undo/redo history
- CSV import/export

---

## Critical Files

| File | Action |
|---|---|
| `Package.swift` | Add iOS platform, `JobApplicationShared` target, conditional deps for Sparkle/ACP/MarkdownUI |
| `Sources/JobApplicationWizardCore/Models.swift` | Move to `JobApplicationShared/`; `#if os` for `NSColor` (line 530) with full `UIColor` implementation |
| `Sources/JobApplicationWizardCore/Dependencies/PersistenceClient.swift` | Extract cross-platform interface to shared target |
| `Sources/JobApplicationWizardCore/Features/App/AppFeature.swift` | Extract `ViewMode` enum to shared target; add `import JobApplicationShared` |
| `Sources/JobApplicationWizardCore/Features/Cuttle/CuttleContext.swift` | Extract `CuttleContext` enum ONLY (not the modifiers/views) to shared target |
| `Sources/JobApplicationWizardCore/Features/Cuttle/AgentActionParser.swift` | Extract `AgentActionMode` enum (lines 191-194) to shared target |
| `Sources/JobApplicationWizardCore/Dependencies/DocumentClient.swift` | Extract `DocumentType` enum ONLY to shared target |
| `Sources/JobApplicationWizardCore/Dependencies/JobURLClient.swift` | Extract `ATSProvider` enum to shared target |
| All files with `import Sparkle/ACP/MarkdownUI` | Wrap in `#if canImport(...)` / `#if os(macOS)` guards |

---

## Verification

1. **After Phase 1:** `swift build` succeeds for macOS; `swift build` for iOS simulator succeeds for `JobApplicationShared`; existing snapshot tests pass; no `NS*` types in shared target
2. **After Phase 2:** iOS app launches in Simulator; widget shows job counts; share extension captures a URL and creates a wishlist job; notification fires for a scheduled interview; exported JSON imports correctly on macOS
3. **After Phase 3:** Add a job on iOS, see it appear on macOS via Google Drive; change status on macOS, see it on iOS; edit different jobs on both devices offline, reconnect, both edits preserved
