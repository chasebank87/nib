# Backlog

Independently testable tickets. Status: `done` means this repository already includes it. Order is the suggested implementation sequence after Phase 0.

---

## NIB-000 — Inception package and vertical slice

- **Status:** done (this change)
- **Goal:** Ship documents, module boundaries, a buildable Mac window, and a linked Zig core.
- **Scope:** README, architecture, product, ADRs, roadmap, this backlog, app slice, themes, FFI, tests, CI.
- **Acceptance:** Documents exist; Zig tests pass with Zig 0.16; on macOS the package tests and `xcodebuild` succeed; no AI network or shell execution.
- **Dependencies:** none
- **Suggested tests:** Domain document codec; CoreBridge version/UTF-8; Zig unit tests.
- **Layer:** both

---

## NIB-001 — Encoding policy and line-ending hardening

- **Status:** done
- **Goal:** Never silently corrupt bytes; preserve LF/CRLF/CR on round-trip, including mixed-ending detection.
- **Scope:** `TextDocumentModel` + `UTF8DocumentCodec` (+ future encoding table). User-facing error when validation fails. Optional “open as Latin-1 / convert to UTF-8” comes later — this ticket only refuses or documents conversion.
- **Acceptance:** LF, CRLF, and CR fixtures save back identically. Invalid UTF-8 throws `DocumentError.invalidUTF8` and does not produce a document. Mixed endings pick a documented rule and do not crash.
- **Dependencies:** NIB-000
- **Suggested tests:** Fixture files for each ending; invalid sequence `0x80`; empty file.
- **Layer:** Swift (Zig already validates UTF-8)

---

## NIB-002 — Autosave and recovery policy

- **Status:** done
- **Goal:** Predictable behavior on crash and sleep.
- **Scope:** Decide `autosavesInPlace` vs app-support recovery copies. Document in PRODUCT/ARCHITECTURE. Implement the chosen path on `NibDocument`.
- **Acceptance:** Written policy. Killing the app after an edit either restores the buffer or clearly does not — no half-written files. Tests for the recovery serializer if app-support copies are used.
- **Dependencies:** NIB-001
- **Suggested tests:** Serialize/deserialize recovery payload; no UI test required in this ticket.
- **Layer:** Swift

---

## NIB-003 — Go to line and column

- **Status:** done
- **Goal:** Jump from the keyboard.
- **Scope:** Command + overlay or panel; parse `line`, `line:column`. Move TextKit selection. Palette entry.
- **Acceptance:** `12` and `12:4` move the caret; out-of-range clamps; works on empty documents.
- **Dependencies:** NIB-000
- **Suggested tests:** Line/column parser unit tests; optional UI test later.
- **Layer:** Swift

---

## NIB-004 — Editor settings persistence

- **Status:** done
- **Goal:** Font, size, line height, tab width, tabs-vs-spaces, wrapping, ligatures persist across launches.
- **Scope:** Domain `EditorSettings`, `SettingsStoring` implementation, apply to `NSTextView`. No theme editor.
- **Acceptance:** Changing tab width and font survives relaunch (unit test with memory store + a UserDefaults suite). Invalid stored values fall back to defaults.
- **Dependencies:** NIB-000
- **Suggested tests:** Decode defaults; reject garbage JSON/plist values.
- **Layer:** Swift

---

## NIB-005 — Command registry

- **Status:** done
- **Goal:** Palette lists real, filterable commands instead of a hard-coded quartet.
- **Scope:** `CommandRegistry` with id, title, keywords, keyboard shortcut, enabled predicate, `async` perform. Palette fuzzy filter. Menu items can share ids.
- **Acceptance:** Registering a command makes it appear and run; disabled commands are hidden or dimmed per a documented rule; filter is stable for empty query.
- **Dependencies:** NIB-000
- **Suggested tests:** Registry lookup; fuzzy rank; enablement.
- **Layer:** Swift

---

## NIB-006 — File watcher and external-change conflict

- **Status:** done
- **Goal:** Detect disk changes while a document is open.
- **Scope:** `DispatchSource` / `NSFilePresenter` on `NibDocument`. Alert: keep, reload, or compare later. No silent overwrite.
- **Acceptance:** Touching the file on disk with the window open presents a conflict path. Reloading a clean document updates the buffer. Dirty + external change never discards without confirmation.
- **Dependencies:** NIB-001
- **Suggested tests:** Presenter callback → state machine unit tests with a fake presenter.
- **Layer:** Swift

---

## NIB-007 — Language detection

- **Status:** done
- **Goal:** Know what language the current file is without a server.
- **Scope:** Implement `LanguageDetecting` with extension, filename, shebang, user override. Descriptors for the priority languages.
- **Acceptance:** `Package.swift` → Swift; `Dockerfile` filename rules if added; `#!/usr/bin/env python3` → Python; override wins. Unknown → `plain-text`.
- **Dependencies:** NIB-000
- **Suggested tests:** Table-driven URL + first-line cases.
- **Layer:** Swift

---

## NIB-008 — Tree-sitter highlighting pipeline

- **Status:** done (JSON / Markdown / Python via Tree-sitter; other priority languages via regex fallback)
- **Goal:** Incremental syntax color mapped to theme tokens.
- **Scope:** Tree-sitter C + grammars for at least JSON, Markdown, and one programming language. `SyntaxHighlighting` service applies attributes on a background queue; MainActor applies to TextKit. Remaining priority languages can follow in child tickets.
- **Acceptance:** Editing a JSON file recolors incrementally without blocking typing. No LSP required. Missing grammar degrades to plain text.
- **Dependencies:** NIB-007, NIB-004
- **Suggested tests:** Parse fixture → expected capture ranges; edit + incremental update.
- **Layer:** Swift (C grammar libs); Zig later if the hot path moves

---

## NIB-009 — Find and replace

- **Status:** done
- **Goal:** In-file search that matches modern editor expectations.
- **Scope:** Find, replace, find-in-selection, regex, case, whole word. Start with the system find bar if it meets the bar; replace with a custom overlay + Zig search if not.
- **Acceptance:** Each mode has a fixture test. Regex compile errors are shown, not crashed. Replace all is one undo group.
- **Dependencies:** NIB-000; Zig search only if we leave the system find bar
- **Suggested tests:** Search primitive tests (Swift or Zig) on a small buffer.
- **Layer:** Swift, or both if Zig search lands

---

## NIB-010 — Large-file thresholds

- **Status:** done
- **Goal:** Never freeze the app on a huge log or generated file.
- **Scope:** Domain constants + `DocumentCapability` flags. Disable wrap, live highlight, minimap, and LSP above thresholds. Warn on open.
- **Acceptance:** Opening a generated multi-megabyte fixture does not beachball in a timed test harness; UI shows reduced-feature state. Thresholds documented.
- **Dependencies:** NIB-001, NIB-008 (for disabling highlight)
- **Suggested tests:** Capability matrix vs file size; codec on a large in-memory buffer.
- **Layer:** Swift

---

## NIB-011 — LSP document lifecycle

- **Goal:** A correct client before feature completeness.
- **Scope:** stdio JSON-RPC, start/stop, `initialize`, `didOpen`/`didChange`/`didClose`, request cancellation, crash restart policy. No completion UI required in this ticket.
- **Acceptance:** Fake server test process receives open/change/close. Killing the server does not crash nib. Cancellation is observable in the fake.
- **Dependencies:** NIB-001, NIB-007
- **Suggested tests:** Integration against a tiny fake LSP executable.
- **Layer:** Swift

---

## NIB-012 — LSP completion, diagnostics, and hover

- **Goal:** First useful IDE loop on the current file.
- **Scope:** Map protocol types to Domain; overlay UI; diagnostic gutter marks (simple).
- **Acceptance:** Fake server can inject a diagnostic and a completion item; accepting a completion edits the document via undo.
- **Dependencies:** NIB-011
- **Suggested tests:** Mapper unit tests; fake-server integration.
- **Layer:** Swift

---

## NIB-013 — Mock AI provider and explain-selection

- **Goal:** Exercise the AI architecture without paid APIs.
- **Scope:** `MockAIProvider`, `ContextDisclosure` sheet, “Explain this selection” command. No HTTP. No tools.
- **Acceptance:** With mock configured, a selection produces a canned explanation overlay. With no provider, the command explains that AI is unconfigured. Nothing leaves the device.
- **Dependencies:** NIB-005
- **Suggested tests:** Mock returns a fixed response; disclosure includes selection length.
- **Layer:** Swift

---

## NIB-014 — Keychain secret store

- **Goal:** Real `SecretStoring` for provider keys.
- **Scope:** Keychain implementation + in-memory fake for tests. Settings UI can set/delete a key. Never log secret material.
- **Acceptance:** Store/retrieve/delete round-trip in tests (fake). Production type uses `kSecClassGenericPassword` with service `com.chaseelder.nib`.
- **Dependencies:** NIB-013
- **Suggested tests:** Fake store; do not hit the real Keychain in CI unless isolated.
- **Layer:** Swift

---

## NIB-015 — Agent permission gate and diff apply

- **Goal:** No silent writes.
- **Scope:** `ToolPermission` prompts, apply-patch tool that produces a Domain diff, review overlay, apply through `NibDocument` (undoable). Still no arbitrary shell.
- **Acceptance:** Apply without grant is denied. Granted apply changes the buffer and can be undone. Denied grant leaves the file untouched.
- **Dependencies:** NIB-013, NIB-001
- **Suggested tests:** Permission matrix; patch apply on a string document.
- **Layer:** Swift; Zig later for diff quality

---

## NIB-016 — Zig search primitives

- **Goal:** Fast literal/regex-ready search on large buffers without blocking UI design.
- **Scope:** C ABI: find all ranges for a pattern (literal first). Swift wrapper + cancellation at the actor boundary.
- **Acceptance:** Zig tests for empty, unicode, overlapping literals. Swift contract tests. No GUI dependency.
- **Dependencies:** NIB-000
- **Suggested tests:** Zig unit + FFI contract.
- **Layer:** both

---

## NIB-017 — Zig text buffer

- **Goal:** Move the durable buffer out of `String` when metrics say so.
- **Scope:** Rope or piece table behind the existing C ABI. Swift model talks to CoreBridge. TextKit remains the view until a custom surface exists.
- **Acceptance:** Insert/delete/read at offsets; UTF-8 invariant; benchmarks checked into `make bench`. Round-trip with the document codec.
- **Dependencies:** NIB-016, NIB-010
- **Suggested tests:** Zig randomized edits vs a reference `ArrayList(u8)`; FFI ownership tests.
- **Layer:** both

---

## NIB-018 — Accessibility and keyboard audit

- **Goal:** Palette, alerts, and the editor are usable with VoiceOver and full keyboard access.
- **Scope:** AX labels on overlays, focus return after palette dismiss, contrast check against theme tokens.
- **Acceptance:** Written checklist signed off against VoiceOver on macOS 15; no unlabeled buttons in the palette.
- **Dependencies:** NIB-005
- **Suggested tests:** UI tests for palette focus; snapshot optional.
- **Layer:** Swift
