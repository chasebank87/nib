# Product

## Vision

nib is a premium native macOS editor for a single file. It should feel like one piece of glass or slate: calm, focused, fast, and free of IDE clutter — while still offering modern language intelligence and agentic help when the user asks.

The competitor is not “another VS Code skin.” The competitor is the moment an engineer opens one file and does not need the rest of the IDE. nib keeps that moment, then lets power arrive through the keyboard.

## Target user

Primary: professional software engineers who already have a repository, a terminal, and often a full IDE, but want a dedicated, beautiful window for the file in front of them.

Secondary: anyone who lives in text files (configs, SQL, Markdown, notes next to code) and wants a Mac-native editor that will grow IDE features without becoming an IDE by default.

The user is keyboard-fluent, appearance-sensitive, and skeptical of tools that send source code to the cloud without asking.

## Primary workflows

1. **Open and edit.** Launch, open a file (or start untitled), type, save. Undo works. The window looks like it belongs on macOS.
2. **Understand this file.** Later: syntax color, go to line, find, hover, outline, Markdown preview as a temporary overlay.
3. **Fix this file.** Later: diagnostics, quick fixes, format, “fix this diagnostic” via AI with a visible diff.
4. **Ask and change.** Later: explain/edit selection, generate tests, agent task with a plan, tool calls, and approval.
5. **Put it away.** Close the window. No workspace to babysit. Recent files remain available through the system document controller.

## UX principles

- The editor is the product. Chrome is temporary.
- Overlays (palette, AI, diff, diagnostics, preview) are dismissible and keyboard-driven.
- No split panes in v1. No custom tab bar. System window tabbing is allowed if the user enables it.
- Light, Dark, and system-automatic appearance. Themes are first-class.
- Prefer native controls for accessibility. Custom drawing is reserved for the editor surface and overlays that AppKit cannot express.
- Motion is restrained. Nothing bounce-loads a file.

## Non-goals (v1)

- Multi-root workspaces, project view, or a permanent file tree
- Built-in terminal or debugger
- Split editors
- Electron, WKWebView editor, or a browser-rendered text engine
- Remote-SSH as a first-class workspace
- Sandboxed Mac App Store distribution (revisit after agent/LSP story)
- Telemetry or growth analytics
- Multi-cursor in the first vertical slice (planned, not this slice)
- Command-line launcher (Phase 6+)
- Plugin marketplace
- Copying proprietary themes or icons

## Feature requirements by phase

### Phase 0 — Foundation

Inception documents, module boundaries, buildable app slice, Zig FFI proof, theme tokens, command palette, tests for the document model and bridge.

### Phase 1 — Native file editor MVP

Reliable open/edit/save, encodings policy, line-ending preservation, recovery snapshots (no in-place autosave), go to line, editor settings (font, tabs, wrap), file watching, external-change conflict, drag and drop, recent files, Finder reveal.

### Phase 2 — Themes, syntax, search

Shipped themes + user theme JSON from Application Support, Tree-sitter highlighting (JSON / Markdown / Python) with regex fallbacks, language detection, find/replace overlay, line numbers, large-file capability matrix.

### Phase 3 — LSP and IDE capabilities

Document-centric LSP with PATH auto-detection (Pyright, typescript-language-server, SourceKit, ZLS, …), optional demo FakeLSP, underlined diagnostics with hover, completion, and hover info. Real server install UI, definition/references/rename, and formatting follow. Useful with language server off.

### Phase 4 — AI selection actions

Mock AI provider and Explain Selection (`⇧⌘E`) are wired locally. Keychain secrets, disclosure sheet polish, ghost text, and edit/fix actions follow.

### Phase 5 — Agents

Orchestrator, tool permission model, workspace search only when granted, approved commands, Git status/diff tools, patch preview, explicit apply.

### Phase 6 — Release polish

Accessibility audit, performance pass, Markdown preview overlay, compact Git diff, Share/Quick Look, optional CLI launcher, notarization path.

## MVP acceptance criteria

The **product MVP** is Phase 1 complete, not merely this slice. Phase 1 is accepted when:

1. A user can create, open, edit, and save UTF-8 files without data loss for supported encodings.
2. Line endings are preserved on a clean round-trip for LF, CRLF, and CR.
3. Untitled documents, dirty titles, save, save as, and close-with-prompt behave like a Mac document app.
4. Undo/redo works for typing and grouped edits.
5. Light, Dark, and system appearance apply to the editor chrome and surface.
6. The command palette can invoke the core file commands from the keyboard.
7. Invalid or unsupported encodings are refused with a clear error; bytes are not silently corrupted.
8. The app works offline with no AI or LSP configured.
9. Automated tests cover the document codec and Zig FFI; CI builds on macOS.

**This slice** additionally requires: Zig core linked, two built-in themes, a command registry in the palette, and documented seams for LSP/AI/buffer work.

## Assumptions

These are working assumptions, not silent product inventions:

- English UI only for MVP
- One file per window
- Recent files via `NSDocumentController`
- Multi-cursor is a later Phase 1–2 enhancement
- Unsandboxed process for v1 so LSP, Git, and approved shell tools can run
- Bundle identifier `com.chaseelder.nib`
- Deployment target macOS 14.0
