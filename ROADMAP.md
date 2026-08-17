# Roadmap

Phases are capability slices, not calendar estimates. Each phase should leave `main` buildable.

## Phase 0 — Product and architecture foundation

**Goal.** A repository a principal engineer can extend without guessing.

- Inception documents (README, product, architecture, ADRs, backlog)
- Module folders and dependency rules
- Makefile, XcodeGen project, Swift package, GitHub Actions
- Smallest native vertical slice: window, TextKit editor, Open/Save/Save As, dirty state, undo, palette placeholder, light/dark themes
- Zig static library linked through CoreBridge (`version`, UTF-8 validate)
- Unit tests for the document model and FFI
- Seams (protocols + models) for LSP, AI, secrets, Git — no implementations that talk to the network or a shell

**Exit.** `make test-zig` passes wherever Zig is installed. On macOS, `make test-swift` and `make build` succeed.

## Phase 1 — Native file editor MVP

**Goal.** Daily-driver plain-text editing.

- Encoding policy beyond UTF-8; refuse or convert explicitly
- Line-ending preservation hardened (mixed endings)
- Autosave and crash recovery that is predictable
- Go to line/column
- Editor settings: font family/size, ligatures, line height, tabs/spaces, tab width, wrapping, whitespace
- File watching and external-change conflict
- Drag and drop onto the dock/window
- Recent files, Finder reveal
- Title/subtitle path
- Large-file warning threshold (even if reduced-feature mode is still crude)

**Exit.** PRODUCT.md MVP acceptance criteria 1–9.

## Phase 2 — Themes, syntax highlighting, and search

**Goal.** The file is readable as code.

- User-selectable themes; load extra JSON from a well-known directory
- Language detection: extension, filename, shebang, override
- Tree-sitter highlight pipeline + theme token mapping
- Find, replace, find-in-selection, regex, case, whole word
- Configurable line numbers, current-line highlight, indent guides, bracket matching
- Minimap and folding remain optional/off by default
- Zig search primitives if Swift regex + TextKit find bar is not enough
- Large-file reduced-feature mode (disable wrap, live highlight, etc.)

**Exit.** Priority languages colorize without LSP. Search is keyboard-complete.

## Phase 3 — LSP and IDE capabilities

**Goal.** IDE power on the current file.

- Server install/config UI (palette/settings), stdio client, document lifecycle
- Incremental sync, cancellation, sensible timeouts
- Diagnostics, completion, hover, definition/declaration, references, rename
- Code actions, document symbols, formatting (on demand and optional on save)
- Semantic tokens when the server provides them
- Error states: server missing, crashed, or slow — editor stays usable

**Exit.** TypeScript or Python (one well-configured server) can complete, jump, and show diagnostics on the open file.

## Phase 4 — AI autocomplete and selection actions

**Goal.** Help on the selection without an agent.

- Mock provider + one HTTP adapter behind `AIProvider`
- Keychain-backed `SecretStoring`
- Context disclosure sheet
- Inline ghost text: accept, dismiss, partial accept if feasible
- Explain / edit / document / generate / fix diagnostic / ask about this file
- All edits previewable and undoable

**Exit.** A user with no key still edits normally. A user with a mock provider can explain and edit a selection.

## Phase 5 — Agentic tools, permission gates, and diff review

**Goal.** An agent that cannot act invisibly.

- Orchestrator with visible plan, tool calls, and progress
- `ToolPermission` grants and prompts
- Tools: read file/selection, optional nearby context, granted workspace search, diagnostics, apply patch, approved command, Git status/diff
- Compact diff review overlay
- No autonomous loops that write or execute without confirmation

**Exit.** An agent run can propose a patch and apply it only after approval; denying a permission produces a clear, non-destructive outcome.

## Phase 6 — Polish, performance, accessibility, and release

**Goal.** Ship-quality Mac utility.

- Accessibility audit (VoiceOver on editor, palette, overlays)
- Performance: open/scroll/search on large files; Instruments pass
- Markdown preview as a temporary mode/overlay
- Git-aware modified indicator; blame/history still optional
- Quick Look, Share Sheet
- Optional command-line launcher
- Notarization / Hardened Runtime
- Icon, about panel, first-run appearance

**Exit.** A stranger can download a build, open a file, and understand the product in one sitting.
