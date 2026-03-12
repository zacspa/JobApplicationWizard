# Job Application Wizard

A native macOS app for managing your job search — track applications on a Kanban board, save job descriptions before they disappear, manage contacts and interview rounds, and get AI-powered help from Claude.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Kanban Board
Drag-and-drop style pipeline across all application stages: Wishlist → Applied → Phone Screen → Interview → Offer → Rejected / Withdrawn. Filter by status, search across all applications, and toggle between kanban and list views.

### Job Detail
Each application has a full detail panel with tabbed sections:

- **Overview** — Company, title, location, salary, URL, timeline, resume version, labels, and excitement rating
- **Description** — Full-text job description storage (paste it before the posting disappears). Print, Save PDF, or Copy with one click.
- **Notes** — Free-form notes: salary research, recruiter details, anything relevant
- **Contacts** — Track recruiters, hiring managers, and referrals with name, title, email, LinkedIn, and connected status
- **Interviews** — Log each interview round with type, date, interviewers, and notes
- **AI** — Multi-turn Claude chat assistant (see below)

### AI Chat Assistant (Claude)
A full conversational chat interface powered by Claude, scoped to the job you're viewing. The system prompt always includes the job title, company, status, and full description — so Claude has full context without you having to paste it.

**Quick-start modes** (pre-populated prompts):
| Mode | What it does |
|---|---|
| Chat | Open-ended conversation about the application |
| Tailor Resume | Paste your resume; get keyword matching and bullet suggestions |
| Cover Letter | Paste your background; get a tailored 3–4 paragraph cover letter |
| Interview Prep | Generate behavioral + technical questions with STAR-framework answers |
| Analyze Fit | Paste your experience; get a fit score and gap analysis |

After sending a specialized mode prompt, the interface resets to Chat so follow-up questions are natural. The full conversation history is sent with every request for genuine multi-turn context.

### Other
- **PDF Export** — Generate a clean PDF of any job description via NSPrintOperation
- **Labels** — Tag applications with preset or custom color-coded labels (Remote, Hybrid, Dream Job, etc.)
- **Favorites & Excitement** — Star favorites and rate excitement 1–5 for quick prioritization
- **Persistence** — Applications saved to JSON in `~/Library/Application Support`. API key stored in the system Keychain.

---

## Requirements

- macOS 14 (Sonoma) or later
- A [Claude API key](https://console.anthropic.com/) for AI features (optional — all other features work without it)

---

## Installation

### Download (easiest)
Download `JobApplicationWizard.dmg` from the [latest release](../../releases/latest), open it, and drag the app to your Applications folder.

### Build from source
Requires Xcode command-line tools.

```bash
git clone https://github.com/zacspa/JobApplicationWizard
cd JobApplicationWizard
swift build -c release
bash build_dmg.sh
open JobApplicationWizard.app
```

---

## Setup

1. Launch the app
2. Open **Settings** (⌘,) and paste your Claude API key
3. Click **+ New Job** to add your first application

The API key is stored securely in the macOS Keychain and never leaves your machine except for direct calls to the Anthropic API.

---

## Architecture

Built with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) by Point-Free.

```
Sources/JobApplicationWizard/
├── App.swift                          # SwiftUI App entry, Window scenes
├── Models.swift                       # JobApplication, JobStatus, Contact,
│                                      #   InterviewRound, AIAction, ChatMessage
├── Features/
│   ├── App/AppFeature.swift           # Root reducer — job list, search, filter
│   ├── AddJob/AddJobFeature.swift     # Add job form reducer
│   └── JobDetail/JobDetailFeature.swift  # Detail reducer — all tabs + AI chat
├── Dependencies/
│   ├── ClaudeClient.swift             # Anthropic API — multi-turn chat
│   ├── PersistenceClient.swift        # JSON load/save, CSV export, NSSavePanel
│   ├── PDFClient.swift                # NSPrintOperation, PDF generation
│   └── KeychainClient.swift           # Secure API key storage
└── Views
    ├── JobDetailView.swift            # Detail panel + all tab views + chat UI
    ├── ContentView.swift              # Root layout (NavigationSplitView)
    ├── SidebarView.swift              # Sidebar navigation
    ├── KanbanView.swift               # Kanban board
    ├── ListView.swift                 # List view
    ├── AddJobView.swift               # Add job form
    └── SettingsView.swift             # Settings panel
```

**Key TCA patterns used:**
- `BindingReducer()` + flat state for all form fields (avoids NavigationSplitView first-responder issues with nested stores)
- `@Dependency` for all external clients (Claude, Persistence, PDF, Keychain)
- `.cancellable(id:cancelInFlight:true)` on AI requests
- Delegate actions for cross-feature communication (jobUpdated, jobDeleted)

---

## License

MIT
