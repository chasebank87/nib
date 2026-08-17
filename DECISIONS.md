# Architecture decision records

Decisions are listed oldest-first. Status is `accepted` unless noted. Revisit when evidence changes; do not revisit for novelty.

## ADR-001 — SwiftUI and AppKit composition

**Context.** The app must feel like a Mac document editor (Open, Save, dirty, versions-ready) and also host SwiftUI overlays (palette, settings, future AI/diff).

**Decision.** Use AppKit `NSDocument` for file lifecycle and window ownership. Use SwiftUI for chrome, overlays, and settings. Host TextKit through `NSViewRepresentable`. Use a SwiftUI `@main` `App` plus `NSApplicationDelegateAdaptor` so we keep a standard menu bar (including Edit / undo).

**Consequences.**

- We do **not** use `DocumentGroup` / `FileDocument` as the source of truth. Those APIs snapshot whole files in memory and fight large-file strategy.
- `NibDocument` is `@objc(NibDocument)` and registered in `Info.plist`.
- Views take bindings or a small session object; they do not own persistence.
- System window tabbing may group documents; we will not ship a custom tab bar.

**Rejected.** Pure SwiftUI `DocumentGroup` (large-file and encoding control). Pure AppKit with no SwiftUI (overlays and settings would be rebuilt later).

## ADR-002 — Text system: hybrid TextKit 2

**Context.** Three options: (1) `NSTextView` / TextKit 2, (2) a fully custom `NSView` layout engine, (3) hybrid.

**Decision.** Hybrid for MVP through Phase 3:

- TextKit 2 `NSTextView` for typing, IME, marked text, selection, undo, Services, spell-check hooks, and accessibility.
- Independent `TextDocumentModel` as the durable snapshot.
- Overlay / sibling views for gutter, diagnostics, folding marks, ghost text, and diff indicators as those features land.
- A `TextSurface` protocol so the renderer can be replaced without rewriting Domain or Services.

**Why not fully custom.** Native text input and accessibility are the hardest parts of an editor. A custom engine would consume the entire v1 schedule and still feel less Mac-like. Novelty is not a reason.

**Known gaps.**

- Multi-cursor is not native. Defer past this slice; implement as layered selections or accept single-cursor until measured.
- Very large files: TextKit will struggle. Mitigate with size thresholds and reduced-feature mode (Phase 2), not a custom engine on day one.
- Code folding is awkward. Plan overlay + elision later; do not block MVP.

**Phase 1 buffer.** Swift `String` / `NSTextStorage`. Zig rope/piece table moves in when search, multi-cursor transactions, or large-file metrics demand it.

## ADR-003 — Zig boundary and initial responsibilities

**Context.** Zig should provide real value without leaking through the app.

**Decision.** Zig is a static library (`libnib_core`) with a minimal C ABI. Swift sees only `CoreBridge`.

**In Zig now:** version, UTF-8 validation (proves compile, link, ownership, tests).

**Next in Zig:** search primitives, then diff, then the text buffer.

**Stay in Swift:** UI, `NSDocument`, file coordination, LSP, AI HTTP, Keychain, Git process wrappers, settings.

**Rules.** Caller-owned input buffers; integer error codes; UTF-8 only; serialized calls until thread safety is documented; FFI tests independent of the GUI.

**Apple ld.** On macOS, `zig build` plus `make zig` rewrite `libnib_core.a` with `ranlib -D` and then `libtool -static`. `libtool` alone on Zig’s `llvm-ar` output drops `libnib_core_zcu.o` and the C ABI symbols vanish at link time. Do not link Zig’s raw archive.

## ADR-004 — Syntax highlighting and parsing

**Context.** Highlighting must be incremental, language-extensible, and useful without LSP.

**Decision.** Tree-sitter (C library) as a Swift service in Phase 2. Grammars version independently of the UI. Capture names map to theme syntax tokens. Semantic tokens from LSP, when present, overlay Tree-sitter.

**Why Tree-sitter.** Incremental edits, existing grammars for the priority languages (TS/JS, JSON, Markdown, Python, Swift, Zig, SQL, YAML, Shell), and a path to later move the hot path into Zig without changing the language-definition files.

**Rejected.** Regex-only TextMate clones as the long-term engine (acceptable as a fallback for unparsed languages). Writing a parser generator. Putting Tree-sitter inside Zig in Phase 0 (keeps the FFI surface small).

## ADR-005 — LSP implementation

**Context.** We need diagnostics, completion, hover, navigation, rename, code actions, symbols, formatting, and optional semantic tokens.

**Decision.** A lean Swift JSON-RPC stdio client, document-centric (the current file). Incremental sync, request IDs, and cancellation from the start. Per-language server install/config is user-visible. Missing servers are not errors for the editor.

**Rejected.** Embedding one language’s compiler. Implementing LSP in Zig. Workspace-wide indexing in v1.

## ADR-006 — AI providers and permission model

**Context.** AI must be provider-agnostic, local-first, and incapable of silent side effects.

**Decision.** Separate packages of responsibility:

1. Transport (`AIProvider`)
2. Model capabilities
3. Prompt / context construction + `ContextDisclosure`
4. Tool definitions (`AgentTool`)
5. Tool execution + `ToolPermission`
6. UI presentation
7. Edit application / diff review

Start with a **mock provider** (Phase 4). No vendor SDK in Domain. Keys via `SecretStoring` (Keychain). This slice ships protocols and value types only — no network, no shell, no agent loop.

**Permissions (flags, not strings):** read current file, read nearby project context, search workspace, read diagnostics/LSP, apply edits, run command, inspect Git, send data to a provider.

**Policy.** Never silently modify a file, run a command, access a workspace, use Git, or send data to a provider. AI edits apply through the document undo stack after preview.

## ADR-007 — Theme format and semantic tokens

**Context.** Themes are first-class and must not scatter colors through views.

**Decision.** Versioned JSON (`schemaVersion: 1`), semantic token keys (`editor.background`, `diagnostic.error`, …), optional syntax map from scope name → token. Two shipped themes: `nib-light`, `nib-dark`, inspired by macOS materials, not copied from proprietary themes.

**Why JSON, not TOML.** `Codable` with zero extra dependencies. A future importer can still ingest other formats into this schema.

**Runtime.** Decode into `Theme`. Views ask for `Color` via token. Missing tokens fall back to documented defaults. User-selected theme + system appearance pick the built-in pair unless the user pins one.

## ADR-008 — Local data and Keychain

**Context.** Settings, recent files, and secrets have different threat models.

**Decision.**

- Document bytes: user-chosen paths via `NSDocument`. No extra copy of source in app support unless recovery requires it (Phase 1 policy).
- Preferences: `UserDefaults` for appearance and editor settings.
- Recent files: `NSDocumentController`.
- API keys (Phase 4): Keychain through `SecretStoring`. Never UserDefaults, never gitignored dotenv files in-repo.
- Recovery: dirty buffers are snapshotted under Application Support (`com.chaseelder.nib/Recovery`). The original file is never autosaved in place.
- Telemetry: not implemented.

## ADR-009 — App Sandbox off for v1

**Context.** A sandboxed editor cannot freely launch LSP servers, Git, or user-approved shell tools.

**Decision.** Do not enable App Sandbox in v1. Keep the door open for Hardened Runtime + notarization. Revisit sandboxing when the tool permission model and security-scoped bookmarks can cover real workflows.

**Consequence.** This is a developer tool, not an App Store submission, until a later decision.

## ADR-010 — Explicit save, recovery copies

**Context.** In-place autosave recovers crashes well but can overwrite the user’s file with a half-edited buffer. Classic Mac documents prompt on close and only write on Save.

**Decision.** `NSDocument.autosavesInPlace` is `false`. Saves are explicit. While a document is dirty, nib writes a JSON recovery snapshot to `~/Library/Application Support/com.chaseelder.nib/Recovery/`. On the next launch, if snapshots exist, the user can restore or discard them. Successful save or close deletes that document’s snapshot.

**Line endings.** In-memory text is LF. Save restores the detected ending. Mixed files keep original bytes until the first edit, then save using the majority ending (tie: CRLF, then LF, then CR).

**Encodings.** UTF-8 and UTF-8 with BOM only. UTF-16 BOMs are refused. Invalid UTF-8 is refused. No silent recode.
