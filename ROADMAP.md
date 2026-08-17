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

- Encoding policy beyond UTF-8; refuse or convert explicitly — **done (UTF-8 / UTF-8 BOM only; UTF-16 refused)**
- Line-ending preservation hardened (mixed endings) — **done**
- Autosave and crash recovery that is predictable — **done (explicit save + Application Support recovery)**
- Go to line/column — **done (`⌘L`)**
- Editor settings: font family/size, ligatures, line height, tabs/spaces, tab width, wrapping — **done**
- File watching and external-change conflict — **done**
- Drag and drop onto the dock/window — **done**
- Recent files, Finder reveal — **done**
- Title/subtitle path — **done** (`representedURL` + subtitle)
- Large-file warning threshold (even if reduced-feature mode is still crude) — **done**

**Exit.** PRODUCT.md MVP acceptance criteria 1–9.

## Phase 2 — Themes, syntax highlighting, and search

**Goal.** The file is readable as code.

- User-selectable themes; load extra JSON from Application Support `Themes/` — **done**
- Language detection: extension, filename, shebang, override — **done**
- Tree-sitter highlight pipeline + theme token mapping — **done** (JSON / Markdown / Python; regex fallback for other priority languages)
- Find, replace, find-in-selection, regex, case, whole word — **done** (`⌘F` overlay)
- Configurable line numbers, current-line highlight, indent guides, bracket matching — **partial** (line numbers + settings toggles; indent guides / bracket matching / current-line paint follow-up)
- Minimap and folding remain optional/off by default
- Zig search primitives if Swift regex + TextKit find bar is not enough — deferred (Swift find engine is enough for now)
- Large-file reduced-feature mode (disable wrap, live highlight, etc.) — **done** (`DocumentCapabilities`)

**Exit.** Priority languages colorize without LSP. Search is keyboard-complete.

## Phase 3 — LSP and IDE capabilities

**Goal.** IDE power on the current file.

- Server install/config UI (palette/settings), stdio client, document lifecycle — **partial** (PATH auto-detect + demo FakeLSP + settings toggles; dedicated install UI follows)
- Incremental sync, cancellation, sensible timeouts — **done** (full-document sync + cancel; timeouts follow)
- Diagnostics, completion, hover, definition/declaration, references, rename — **partial** (underlined diagnostics + hover tooltip, completion overlay, hover; navigation/rename follow)
- Code actions, document symbols, formatting (on demand and optional on save)
- Semantic tokens when the server provides them
- Error states: server missing, crashed, or slow — editor stays usable — **done** (missing server shows status; editing continues)

**Exit.** TypeScript or Python (one well-configured server) can complete, jump, and show diagnostics on the open file.

## Phase 4 — AI autocomplete and selection actions

**Goal.** Help on the selection without an agent.

- Mock provider + one HTTP adapter behind `AIProvider` — **done** (`MockAIProvider`, `HTTPOpenAICompatibleProvider`, `RoutedAIProvider`)
- Keychain-backed `SecretStoring` — **done**
- Context disclosure sheet — **done**
- Inline ghost text: accept, dismiss, partial accept if feasible — **done** (Tab / Esc / ⌥Tab word; idle debounce)
- Explain / edit / document / generate / fix diagnostic / ask about this file — **done**
- All edits previewable and undoable — **done** (diff review overlay + buffer replace)

**Exit.** A user with no key still edits normally. A user with a mock provider can explain and edit a selection.

## Phase 5 — Agentic tools, permission gates, and diff review

**Goal.** An agent that cannot act invisibly.

- Orchestrator with visible plan, tool calls, and progress — **done** (`AgentOrchestrator` + plan overlay)
- `ToolPermission` grants and prompts — **done** (controller used by AI + agent steps)
- Tools: read file/selection, optional nearby context, granted workspace search, diagnostics, apply patch, approved command, Git status/diff — **partial** (read selection/diagnostics, complete, apply patch; workspace search / shell / Git follow)
- Compact diff review overlay — **done** (line-oriented `TextDiff` in AI result overlay)
- No autonomous loops that write or execute without confirmation — **done** for current tools

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
