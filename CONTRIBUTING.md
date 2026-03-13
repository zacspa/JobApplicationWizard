# Contributing to Job Application Wizard

Welcome! Job Application Wizard is a macOS app built by and for job seekers. Whether you write code, design interfaces, file bugs, or suggest features — every contribution matters.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). We're building a supportive space for people navigating the job search.

## Ways to Contribute

- **Report bugs** — Something broken? [Open a bug report](../../issues/new?template=bug_report.yml).
- **Suggest features** — Have an idea? [Open a feature request](../../issues/new?template=feature_request.yml).
- **Improve docs** — Typos, unclear instructions, missing info — all welcome.
- **Design & UX** — Mockups, usability feedback, accessibility improvements.
- **Write code** — Bug fixes, new features, test coverage, refactoring.

## Development Setup

### Prerequisites
- macOS 14 (Sonoma) or later
- Xcode 15+ (for Swift 5.9 and macOS SDK)

### Getting started

```bash
git clone https://github.com/zacspa/JobApplicationWizard
cd JobApplicationWizard
swift build
swift test
```

> **Note:** `swift test` requires the macOS SDK provided by Xcode. If you see SDK-related errors, make sure Xcode (not just Command Line Tools) is installed and selected: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

To run the app locally, see the build instructions in the [README](README.md#build-from-source).

## Architecture Overview

The app uses [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) with three Swift package modules:

| Module | Purpose |
|--------|---------|
| `JobApplicationWizardCore` | All features, models, views, and dependencies |
| `JobApplicationWizard` | Executable target (thin wrapper) |
| `JobApplicationWizardTests` | Test suite (85 tests) |

See the [README](README.md#architecture) for the full file tree and TCA patterns used.

> **Note:** Contributors don't need to run `build_dmg.sh` — that's the maintainer release process.

## Making a Pull Request

1. **Fork** the repo and clone your fork
2. **Branch** from `main` — use `feat/short-description` or `fix/short-description`
3. **Make your changes** — keep PRs focused and small when possible
4. **Test** — run `swift test` and verify your change works in the app
5. **Commit** — follow the commit convention below
6. **Push** your branch and open a PR against `main`
7. **Fill out the PR template** — it will auto-populate when you open the PR

## Commit Convention

Use the format `type: description` (lowercase, imperative mood):

| Type | When to use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance, dependencies |
| `build` | Build system or CI changes |
| `test` | Adding or updating tests |
| `refactor` | Code change that neither fixes a bug nor adds a feature |

Examples:
- `feat: add interview reminder notifications`
- `fix: prevent crash when job description is empty`
- `docs: clarify build instructions for Xcode 15`

## What to Expect

- **CI runs automatically** on every PR (build + test)
- **Review within a few days** — we'll provide constructive feedback
- **Small, focused PRs merge faster** than large ones
- **Don't worry about being perfect** — we'd rather help you iterate than have you not contribute

## Questions?

- **General questions:** [GitHub Discussions](https://github.com/zacspa/JobApplicationWizard/discussions)
- **Bugs & features:** [GitHub Issues](https://github.com/zacspa/JobApplicationWizard/issues)

This project grew out of the Square Mafia community of job seekers. We're glad you're here.
