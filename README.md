# nib

A beautiful, lightweight, single-pane native macOS editor for working with one file at a time.

nib is not a workspace-first IDE. It is a calm piece of glass for opening, understanding, editing, and acting on an individual file from a larger codebase — with IDE-grade language intelligence and agentic tools available on demand, never as permanent chrome.

**IDE power without IDE weight.**

## Product statement

Engineers spend much of their day inside a single file: reading, editing, explaining, fixing, and shipping a change. Full IDEs surround that work with sidebars, terminals, activity bars, and tab stacks. nib inverts the default. The editor *is* the product. Supporting tools appear as command palettes, sheets, popovers, and overlays, then get out of the way.

The application is native macOS: Swift for UI, windowing, accessibility, and orchestration; Zig for the performance-sensitive core. There is no Electron, no web view, and no browser-rendered editor shell.

## Core principles

1. **Single-pane by default.** One primary editor. No permanent sidebar, file explorer, terminal, activity bar, or custom tab bar.
2. **Fast and local-first.** Opening, scrolling, searching, highlighting, and editing must feel immediate. Core editing works offline. AI degrades gracefully when no provider is configured.
3. **Native macOS quality.** System menus, keyboard conventions, focus, appearance, typography, and accessibility APIs — not a custom widget kit where AppKit already does it better.
4. **Privacy and user control.** Source code never leaves the device without explicit configuration and consent. API keys live in the Keychain. Telemetry is opt-in and is **not implemented** in the MVP.
5. **Progressive disclosure.** A casual user can open and edit immediately. Advanced IDE and AI features are discoverable through the command palette and keyboard shortcuts.

See [PRODUCT.md](PRODUCT.md) for vision, non-goals, and MVP acceptance criteria.

## Initial feature set

**This repository’s first vertical slice (Phase 0 / early Phase 1):**

- Native macOS document window with a single editor surface
- Open, Save, and Save As for UTF-8 text
- Dirty-state indicator and TextKit undo/redo
- Command palette placeholder (`⌘⇧P`)
- Semantic theme tokens with built-in light and dark themes
- Zig core linked through a C ABI, with a proof-of-integration API and tests

**Designed from the start, implemented in later phases:** syntax highlighting, search, LSP, Git-aware status, inline AI, agent tools with permission gates, and large-file reduced-feature modes. The full map is in [ROADMAP.md](ROADMAP.md) and [BACKLOG.md](BACKLOG.md).

## Architecture overview

```
App        windowing, NSDocument, menus, composition root
UI         editor shell, TextKit surface, overlays, palette
Domain     documents, themes, commands, language and AI models
Services   persistence, settings, future LSP / Git / AI adapters
CoreBridge safe Swift wrappers around the Zig C ABI
ZigCore    buffer/search/diff primitives (UTF-8 validation in this slice)
```

Dependency rule: `App → UI → Services → Domain ← CoreBridge → Zig`. UI never imports Zig. Services never import App.

Details, diagrams, and data flows: [ARCHITECTURE.md](ARCHITECTURE.md).  
Locked decisions: [DECISIONS.md](DECISIONS.md).

## Technology choices

| Layer | Choice | Why |
| --- | --- | --- |
| App / UI | Swift, AppKit `NSDocument`, SwiftUI chrome, TextKit 2 `NSTextView` | Native input, accessibility, undo, document lifecycle |
| Core | Zig static library, C ABI | Performance and a portable, testable boundary |
| Highlighting (Phase 2) | Tree-sitter | Incremental, language-independent of the UI |
| Language intelligence (Phase 3) | LSP over stdio | Existing servers; app remains useful without them |
| AI (Phase 4–5) | Provider protocols + mock first | No vendor lock-in; no network in this slice |
| Themes | Versioned JSON semantic tokens | Human-readable, Codable, future editor/importer |
| Persistence | `NSDocument` + UserDefaults; Keychain later | Native dirty/save; secrets never in files |

## Privacy and AI safety

- No source, diagnostics, terminal output, or repository context is sent to a model until the user configures a provider **and** can see what will be sent.
- Agent tools require a formal permission model. Destructive or externally visible actions need explicit approval.
- Every AI edit is previewable as a diff and reversible through normal undo.
- API keys are stored in the macOS Keychain, never in project files, fixtures, or documentation.
- This slice implements **no** AI networking, shell execution, workspace indexing, or telemetry.

## Development prerequisites

Pinned versions live in [docs/TOOLCHAINS.md](docs/TOOLCHAINS.md).

```bash
brew install zig xcodegen
make setup
```

- macOS 14.0 or later (deployment target)
- Xcode 16+ / Swift 6.0+
- [Zig 0.16.0](https://ziglang.org/download/) (`brew install zig`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — required for `make build` / `make run`, **not** for `make test`
- Optional: SwiftFormat, SwiftLint (`brew bundle` installs them from the Brewfile)

This cloud/Linux checkout **cannot** compile the macOS app. Zig unit tests can run anywhere Zig is installed. Swift and `xcodebuild` require a Mac (or the `macos-15` GitHub Actions runner).

This cloud/Linux checkout **cannot** compile the macOS app. Zig unit tests can run anywhere Zig is installed. Swift and `xcodebuild` require a Mac (or the `macos-15` GitHub Actions runner).

## Build, run, and test

```bash
# Zig core (library + tests)
make zig
make test-zig

# Swift package tests (macOS; builds Zig first)
make test-swift

# Everything the Makefile can run
make test

# Generate Nib.xcodeproj, compile the app (needs XcodeGen)
brew install xcodegen   # once
make build

# Build and launch
make run

# Format / lint (requires SwiftFormat, SwiftLint, zig)
make format
make lint
```

Manual Xcode flow:

```bash
make zig
xcodegen generate
open Nib.xcodeproj
```

## Roadmap

| Phase | Focus |
| --- | --- |
| 0 | Product and architecture foundation (this work) |
| 1 | Native file editor MVP |
| 2 | Themes, syntax highlighting, search |
| 3 | LSP and IDE capabilities |
| 4 | AI autocomplete and selection actions |
| 5 | Agentic tools, permission gates, diff review |
| 6 | Polish, performance, accessibility, release |

See [ROADMAP.md](ROADMAP.md) for scope per phase and [BACKLOG.md](BACKLOG.md) for independently testable tickets.

## Repository layout

```
App/           application lifecycle, NSDocument, menus
UI/            editor shell, text surface, command palette
Domain/        models, theme tokens, command and AI/LSP seams
Services/      persistence, settings, future integrations
CoreBridge/    Swift ↔ Zig FFI
ZigCore/       Zig library, C header, unit tests
Resources/     shipped theme JSON
Tests/         Domain and CoreBridge tests
docs/          toolchain pins
```

## License

No license has been chosen yet. Do not assume redistribution rights until one is added.
