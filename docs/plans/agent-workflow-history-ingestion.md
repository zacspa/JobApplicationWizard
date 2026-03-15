# Agent Workflow: Revertable History, Agent Data Modification, Document Ingestion (v2)

## Context

The app has a chat-only AI interface (Cuttle) that reads job data but cannot modify it. The goal: (1) enable the AI to make structured changes to job data, (2) add drag-and-drop document ingestion, and (3) wrap everything in a revertable event history. This revision addresses the swarm review: event sourcing replaces full-state snapshots, Claude tool_use replaces fragile XML parsing, document attachment is decoupled from AI processing, and history lives in a side-channel dependency rather than the TCA state tree.

---

## Phase 1: Event-Sourced History System

### 1a. Event Model
- **New file:** `Features/History/HistoryEvent.swift`

```swift
HistoryEvent: Codable, Identifiable, Equatable
  id: UUID
  timestamp: Date
  label: String              // "Changed Acme Corp company from 'Acme' to 'Acme Corporation'"
  source: Source             // .user, .agent, .import, .system
  command: HistoryCommand    // reversible command

HistoryCommand: Codable, Equatable (enum)
  .updateField(jobId: UUID, field: AgentWritableField, oldValue: String, newValue: String)
  .setStatus(jobId: UUID, old: JobStatus, new: JobStatus)
  .addNote(jobId: UUID, noteId: UUID)
  .deleteNote(jobId: UUID, snapshot: Note)
  .addContact(jobId: UUID, contactId: UUID)
  .deleteContact(jobId: UUID, snapshot: Contact)
  .addInterview(jobId: UUID, interviewId: UUID)
  .deleteInterview(jobId: UUID, snapshot: InterviewRound)
  .addLabel(jobId: UUID, label: JobLabel)
  .removeLabel(jobId: UUID, label: JobLabel)
  .setExcitement(jobId: UUID, old: Int, new: Int)
  .toggleFavorite(jobId: UUID, old: Bool, new: Bool)
  .addJob(jobId: UUID)
  .deleteJob(jobId: UUID, snapshot: JobApplication)  // full snapshot only for delete
  .addDocument(jobId: UUID, documentId: UUID)
  .deleteDocument(jobId: UUID, snapshot: JobDocument)
  .compound([HistoryCommand])  // groups agent multi-action blocks

AgentWritableField: String, Codable, CaseIterable (enum)
  .company, .title, .location, .salary, .url,
  .jobDescription, .resumeUsed, .coverLetter
  // Explicitly excludes: id, dateAdded, chatHistory, documents, etc.
```

Each command stores old + new values, so `reverse()` is trivial. Compound commands group agent action blocks into a single revertable unit.

### 1b. HistoryClient Dependency (side-channel, not in state tree)
- **New file:** `Dependencies/HistoryClient.swift`

```swift
HistoryClient:
  record: (HistoryEvent) async -> Void
  recentEvents: (Int) async -> [HistoryEvent]      // last N events
  eventCount: () async -> Int
  undoLast: () async throws -> HistoryCommand       // returns command to reverse
  revertTo: (UUID) async throws -> [HistoryCommand] // returns commands to reverse
  checkpoint: ([JobApplication]) async -> Void      // periodic full snapshot for fast replay
  loadCheckpoint: () async -> [JobApplication]?
```

Live implementation:
- Append-only NDJSON file (`history.ndjson`) for events; O(1) writes.
- Periodic checkpoint (`history-checkpoint.json`) every 50 events for fast replay.
- Rolling window: keep last 500 events; prune on write.
- Never loaded into TCA state tree; queried on-demand via effects.

### 1c. HistoryFeature Reducer (lightweight UI state only)
- **New file:** `Features/History/HistoryFeature.swift`

```swift
HistoryFeature.State:
  showTimeline: Bool = false
  visibleEvents: [HistoryEvent] = []  // loaded on-demand when timeline opens
  isTimeTraveling: Bool = false
  revertTargetId: UUID? = nil

HistoryFeature.Action:
  toggleTimeline
  eventsLoaded([HistoryEvent])
  scrubTo(UUID)
  confirmRevert
  cancelTimeTraveling
  delegate(Delegate)
    .applyCommands([HistoryCommand])  // parent applies reversed commands to state.jobs
```

### 1d. Integrate into AppFeature
- **Modify:** `AppFeature.swift`
- Add `history: HistoryFeature.State` and `Scope`.
- Add `@Dependency(\.historyClient) var historyClient`.
- Record events at each mutation site with descriptive labels.
- **Debounce binding edits**: Use a 2-second timer; coalesce consecutive `.jobDetail(.delegate(.jobUpdated))` actions into a single `.updateField` event. Only record when the timer fires or a different action type arrives.
- Handle `history(.delegate(.applyCommands(commands)))` by reversing each command on `state.jobs`.
- Cancel in-flight AI requests when entering time-travel mode.

### 1e. History Timeline UI
- **New file:** `Features/History/HistoryTimelineView.swift`
- Toggle via toolbar button.
- Vertical list of events with timestamp, label, source badge (user/agent/import).
- Each event shows exactly what changed (e.g., "company: Acme -> Acme Corporation").
- "Revert to here" and "Cancel" buttons.
- Time-travel banner over main content; editing disabled during time-travel.

---

## Phase 2: Agent Action Protocol (Dual-Mode)

### 2a. Action Schema
- **New file:** `Features/Cuttle/AgentActionParser.swift`

```swift
AgentAction: Codable, Equatable (enum)
  .updateField(field: AgentWritableField, value: String)  // jobId inferred from context
  .setStatus(status: String)
  .addNote(title: String, body: String)
  .addContact(name: String, title: String?, email: String?)
  .addInterview(round: Int, type: String, date: String?)
  .addLabel(labelName: String)
  .setExcitement(level: Int)

AgentActionBlock: Codable, Equatable
  actions: [AgentAction]
  summary: String
```

Note: `jobId` is NOT in each action; it's inferred from CuttleContext (`.job(id)`). Agent can only modify the docked job.

### 2b. Dual-Mode Extraction
- **Modify:** `ClaudeClient.swift`
- Add `tools` array to the API request with an `apply_actions` tool definition using the `AgentActionBlock` JSON Schema.
- Parse `tool_use` content blocks from the response alongside `text` blocks.
- Return `(String, AITokenUsage, AgentActionBlock?)` instead of `(String, AITokenUsage)`.

- **New file:** `Features/Cuttle/TextActionExtractor.swift`
- Fallback parser for ACP: scans for `<actions>...</actions>` markers.
- Defensive: rejects if markers appear inside code blocks; handles malformed JSON gracefully.

- **Modify:** `CuttleFeature.swift`
- After receiving response, use tool_use extraction (Claude API) or text extraction (ACP).
- If actions present and context is `.job(id)`, emit `delegate(.agentActionsReceived)`.
- If context is not `.job`, ignore any action blocks (agent shouldn't modify without a target).

### 2c. System Prompt Extension
- **Modify:** `CuttlePromptBuilder.swift`
- For `.job(id)` context: append action protocol description with supported fields (the `AgentWritableField` enum cases) and examples.
- For `.global`/`.status`: explicitly instruct "do not emit action blocks."

### 2d. Agent Action Application Setting
- **Modify:** `Models.swift` — `AppSettings`
- Add `agentActionMode: AgentActionMode` (.applyImmediately, .requireApproval), default `.applyImmediately`.
- **Modify:** `SettingsView.swift` — picker in AI Provider tab.

### 2e. AppFeature Action Handling
- **Modify:** `AppFeature.swift`
- Handle `.cuttle(.delegate(.agentActionsReceived(actions, summary)))`:
  - Validate all actions against `AgentWritableField` whitelist.
  - Validate target job exists (from cuttle.currentContext).
  - If `.applyImmediately`: apply actions, record compound `HistoryEvent` with `.agent` source, save.
  - If `.requireApproval`: store in `pendingAgentReview` state, show review sheet.
- Review sheet: shows each proposed change with current vs. new value. Per-action accept/reject checkboxes. Confirm applies selected actions.

```swift
PendingAgentReview: Equatable
  jobId: UUID
  actions: [AgentAction]
  summary: String
  accepted: Set<Int>  // indices of accepted actions; all selected by default
```

---

## Phase 3: Document Model & Tab

### 3a. Document Model
- **Modify:** `Models.swift`

```swift
JobDocument: Codable, Identifiable, Equatable
  id: UUID
  filename: String
  documentType: DocumentType  // .pdf, .docx, .rtf, .txt
  rawText: String
  addedAt: Date
  fileSize: Int?
```

- Add `documents: [JobDocument]` to `JobApplication` with `decodeIfPresent` default `[]`.

### 3b. Documents Tab
- **Modify:** `JobDetailFeature.swift` — add `.documents` Tab case, `deleteDocument(UUID)` action.
- **Modify:** `JobDetailView.swift` — new `DocumentsTab`:
  - List of documents: filename, type icon, date, size.
  - Expandable raw text preview per document.
  - Delete button per document.
  - "Process with AI" button per document (sends to Cuttle for organization).
  - Drop zone on the tab itself for additional drops.

### 3c. Document Extraction Client
- **New file:** `Dependencies/DocumentClient.swift`

```swift
DocumentClient:
  extractText: (URL) async throws -> (text: String, filename: String, type: DocumentType, size: Int)

Live:
  .pdf: PDFKit.PDFDocument(url:)?.string
  .docx/.rtf: NSAttributedString(url:documentAttributes:).string
  .txt/.md: String(contentsOf:encoding:)
```

### 3d. Document-as-Context in Prompts
- **Modify:** `CuttlePromptBuilder.swift`
- In `buildJobPrompt`, add a "Documents" section listing attached documents with their rawText (truncated to 10K chars each). This puts document content in the system prompt context, not in chat message history.

---

## Phase 4: Drag-and-Drop Document Ingestion

### 4a. Drop = Attach (decoupled from AI)
- **Modify:** `KanbanView.swift` — add `.dropDestination(for: URL.self)` on each `JobCard`. Apply AFTER `.cuttleDockable` to avoid gesture conflict.
- **Modify:** `ListView.swift` — add `.dropDestination(for: URL.self)` on rows.
- On drop: emit `AppFeature.Action.documentDropped(jobId: UUID, urls: [URL])`.

### 4b. AppFeature Document Flow
- **Modify:** `AppFeature.swift`

```
.documentDropped(UUID, [URL])
.documentExtracted(UUID, JobDocument)
.documentExtractionFailed(String)
.processDocumentWithAI(jobId: UUID, documentId: UUID)
```

Flow for drop:
1. `.documentDropped`: extract text via `documentClient`.
2. `.documentExtracted`: add `JobDocument` to job's `documents`. Record `.addDocument` history event. Save. **Done.** No AI involvement.
3. Cuttle jumps to the job card (context switch via `.cuttle(.switchContext(.job(id)))`), but does NOT auto-send a message. The user sees the document in the Documents tab and can choose to process it.

Flow for AI processing (opt-in):
1. User clicks "Process with AI" on a document in the Documents tab.
2. `.processDocumentWithAI` sends a message to Cuttle: "Please review the document '[filename]' (shown in the job context) and organize it into the appropriate fields."
3. The document content is already in the system prompt via Phase 3d, so the message is small.
4. Agent responds with action blocks; normal action handling applies.

### 4c. Auto-Process Setting (optional)
- **Modify:** `Models.swift` — `AppSettings`
- Add `autoProcessDocuments: Bool = false`.
- When enabled, `.documentExtracted` also triggers `.processDocumentWithAI` automatically.
- Default off; respects user agency.

### 4d. Visual Feedback
- `processingDocumentJobIds: Set<UUID>` on `AppFeature.State`.
- Progress indicator on cards during extraction.

---

## Phase 5: Testing

### New test files:
- `HistoryEventTests.swift`: Command forward/reverse, compound commands, event serialization.
- `HistoryClientTests.swift`: Append, query, revert, checkpoint, rolling window prune.
- `AgentActionParserTests.swift`: Tool_use extraction, text fallback, malformed JSON, field whitelist validation.
- `DocumentClientTests.swift`: PDF/DOCX/TXT extraction with sample files.

### Modifications:
- `AppFeatureTests.swift`: History recording on mutations, debounced binding edits, agent action application (both modes), document drop flow.
- `CuttleFeatureTests.swift`: Agent action delegate emission.

---

## Files Summary

### New Files (7)
| File | Purpose |
|------|---------|
| `Features/History/HistoryEvent.swift` | Event model, HistoryCommand enum, AgentWritableField whitelist |
| `Features/History/HistoryFeature.swift` | Lightweight TCA reducer for timeline UI state |
| `Features/History/HistoryTimelineView.swift` | Timeline UI, scrubber, time-travel banner |
| `Features/Cuttle/AgentActionParser.swift` | AgentAction schema, AgentActionBlock |
| `Features/Cuttle/TextActionExtractor.swift` | ACP fallback: `<actions>` text parser |
| `Dependencies/DocumentClient.swift` | PDF/DOCX/RTF/TXT text extraction |
| `Dependencies/HistoryClient.swift` | Side-channel history persistence (NDJSON + checkpoints) |

### Modified Files (10)
| File | Changes |
|------|---------|
| `Models.swift` | Add `JobDocument`, `documents` on `JobApplication`, `agentActionMode`, `autoProcessDocuments` on `AppSettings` |
| `AppFeature.swift` | Scope HistoryFeature, record events, debounce bindings, agent action handling, document drop, review sheet |
| `CuttleFeature.swift` | Dual-mode action extraction, new delegate case |
| `CuttlePromptBuilder.swift` | Action protocol schema for job context, documents-as-context section |
| `ClaudeClient.swift` | Add `tools` array with `apply_actions` tool definition, parse `tool_use` response blocks |
| `JobDetailFeature.swift` | Add Documents tab, deleteDocument, processDocumentWithAI actions |
| `JobDetailView.swift` | Add DocumentsTab view with "Process with AI" button |
| `KanbanView.swift` | Add `.dropDestination(for: URL.self)` on job cards |
| `ListView.swift` | Add `.dropDestination(for: URL.self)` on rows |
| `SettingsView.swift` | Add agent action mode + auto-process documents pickers |

---

## Verification

1. **History**: Edit a job field; wait 2s; open timeline; verify event shows "Changed [field] from X to Y"; revert; verify field restored.
2. **Agent actions (immediate, Claude API)**: Dock Cuttle on a job; ask "Add a note about the phone screen"; verify tool_use response parsed; note appears; history shows "AI: Added note".
3. **Agent actions (approval)**: Switch to require approval; repeat; verify review sheet with per-action checkboxes.
4. **Agent actions (ACP fallback)**: Connect ACP agent; repeat; verify `<actions>` text parsing works.
5. **Field whitelist**: Verify agent cannot set `id`, `chatHistory`, or other non-whitelisted fields.
6. **Document attach (no AI)**: Drag PDF onto card; verify document appears in Documents tab; verify NO AI message sent; verify history shows "Added document".
7. **Document + AI (opt-in)**: Click "Process with AI" on attached document; verify agent organizes content; verify document text in system prompt (not in chat message).
8. **Auto-process setting**: Enable setting; drop another PDF; verify AI processing triggered automatically.
9. **Revert agent changes**: After agent modifies fields, revert in timeline; verify fields restored.
10. **Persistence**: Quit and relaunch; verify history events survive; verify checkpoint loads.
11. **Both providers**: Test with Claude API (tool_use) and ACP (text fallback).
