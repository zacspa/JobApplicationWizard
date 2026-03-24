# Cuttle Onboarding: ACP Agent Discovery Step

## Context

New users have no way to discover or connect an ACP agent during the Cuttle onboarding. The current flow teaches Cuttle interactions first, then shows a "go to Settings" step at the end if AI isn't configured. This means users learn about a chat interface they can't actually use yet. The fix: put agent discovery and connection first, so users have AI working before the rest of the tour.

## Changes

### 1. Replace `aiSetup` with two new steps at the front

**File:** `Sources/JobApplicationWizardCore/Features/Cuttle/CuttleOnboardingFeature.swift`

Update `OnboardingStep` enum:
- Add `discoverAgent` and `connectAgent` before `meetCuttle`
- Remove `aiSetup`
- Both new steps filtered out when `aiReady == true` (same pattern as old `aiSetup`)

New step order: `discoverAgent` → `connectAgent` → `meetCuttle` → `expandCollapse` → `chatBasics` → `dragToDock` → `carryOrFresh` → `resize`

### 2. Add state for agent discovery and connection

**File:** `Sources/JobApplicationWizardCore/Features/Cuttle/CuttleOnboardingFeature.swift`

```
availableAgents: [ACPAgentEntry] = []
isLoadingAgents: Bool = false
agentSearchText: String = ""
selectedAgentId: String? = nil
registryError: String? = nil
isConnecting: Bool = false
connectionError: String? = nil
isConnected: Bool = false
connectedAgentName: String? = nil
```

Computed: `filteredAgents` (search filter), `selectedAgent` (lookup by ID)

### 3. Add actions and reducer logic

**File:** `Sources/JobApplicationWizardCore/Features/Cuttle/CuttleOnboardingFeature.swift`

New actions:
- `fetchRegistry` / `registryLoaded(Result<[ACPAgentEntry], Error>)` — fetch on `.start` when first step is `discoverAgent`
- `searchTextChanged(String)` / `selectAgent(String)` — UI bindings
- `connectToAgent` / `connectionResult(Result<String, Error>)` / `retryConnection` — connection flow
- `skipAgentSetup` — jump to `meetCuttle`, skipping both agent steps

New dependencies: `@Dependency(\.acpRegistryClient)`, `@Dependency(\.acpClient)`

New delegate: `.agentConnected(agentId: String, agentName: String)` — parent saves selection and updates shared connection state. Remove `.openSettings` delegate.

### 4. Build the discovery card UI

**File:** `Sources/JobApplicationWizardCore/Features/Cuttle/CuttleOnboardingOverlay.swift`

For `discoverAgent`, render a centered 480px-wide panel (not a positioned tooltip) with:
- Search field to filter agents
- Scrollable agent list (~5 visible) showing: icon, name, version, description, authors, distribution types as badges (npx/uvx/binary)
- When an agent is selected, show install instructions below the list with monospaced code blocks and copy buttons
- Install instructions derived from `ACPDistribution`: npx command, uvx command, binary curl command (informational; the app handles launch automatically)
- "Next" disabled until an agent is selected; "Skip" jumps to `meetCuttle`

For `connectAgent`, render a centered 480px-wide card with:
- Selected agent summary (icon, name, description)
- "Connect" button → spinner while connecting → success message or error with retry
- On success, auto-advance after 1s or user clicks "Next"
- "Back" returns to `discoverAgent`

Both steps use `spotlightTarget = .none` (centered, no spotlight highlight).

### 5. Update AppFeature integration

**File:** `Sources/JobApplicationWizardCore/Features/App/AppFeature.swift`

- Handle `.cuttleOnboarding(.delegate(.agentConnected))`: update `acpConnection` shared state, save `selectedACPAgentId` to settings
- Remove `.openSettings` delegate handler
- Keep existing `aiReady` flag logic on start (filters steps when already connected)

### 6. Update tests

**File:** `Tests/JobApplicationWizardTests/CuttleOnboardingTests.swift`

- Update first-step expectations (`discoverAgent` when `aiReady == false`, `meetCuttle` when `true`)
- Add tests: fetchRegistry on start, registryLoaded success/failure, selectAgent, connectToAgent success/failure, skipAgentSetup, step filtering
- Remove `aiSetup` tests

**File:** `Tests/JobApplicationWizardTests/CuttleOnboardingSnapshotTests.swift` (if exists)

- Add snapshots for discoverAgent and connectAgent cards
- Remove aiSetup snapshot

## Verification

1. `swift build` — no errors or warnings
2. `swift test` — all pass
3. Launch app with no prior settings (`mv ~/Library/Application\ Support/JobApplicationWizard/settings.json /tmp/`), verify onboarding starts at agent discovery
4. Search for an agent, select it, see install instructions, connect, verify auto-advance to meetCuttle
5. Skip agent setup, verify tour continues at meetCuttle without AI
6. Launch with AI already connected, verify onboarding starts at meetCuttle (skips agent steps)
7. "Replay Cuttle Tour" from settings starts at discoverAgent again
