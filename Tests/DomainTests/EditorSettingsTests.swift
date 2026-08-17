import Foundation
import NibDomain
import NibServices
import Testing

struct EditorSettingsTests {
    @Test func sanitizesAndFallsBack() {
        var settings = EditorSettings(
            fontName: "  ",
            fontSize: 120,
            lineHeight: 0.2,
            tabWidth: 99
        )
        settings = settings.sanitized()
        #expect(settings.fontName == EditorSettings.systemMonospaceName)
        #expect(settings.fontSize == 32)
        #expect(settings.lineHeight == 1.0)
        #expect(settings.tabWidth == 16)
        #expect(EditorSettings.decoded(from: "not-json") == .default)
        #expect(EditorSettings.decoded(from: nil) == .default)
    }

    @Test func jsonRoundTripThroughSettingsStore() {
        let store = MemorySettingsStore()
        var settings = EditorSettings.default
        settings.fontSize = 15
        settings.wrapLines = true
        settings.tabWidth = 2
        settings.enableLanguageServer = false
        settings.enableDemoLanguageServer = true
        store.set(string: settings.encodedJSON(), for: EditorSettings.storageKey)
        let loaded = EditorSettings.decoded(from: store.string(for: EditorSettings.storageKey))
        #expect(loaded.fontSize == 15)
        #expect(loaded.wrapLines)
        #expect(loaded.tabWidth == 2)
        #expect(loaded.enableLanguageServer == false)
        #expect(loaded.enableDemoLanguageServer == true)
    }

    @Test func decodesFormatOnSave() {
        let json = #"{"formatOnSave":true,"fontSize":13}"#
        let settings = EditorSettings.decoded(from: json)
        #expect(settings.formatOnSave)
        #expect(EditorSettings.default.formatOnSave == false)
        let omitted = EditorSettings.decoded(from: #"{"fontSize":13}"#)
        #expect(omitted.formatOnSave == false)
    }
}

struct RecoveryStoreTests {
    @Test func memoryRecoveryRoundTrip() throws {
        let store = MemoryRecoveryStore()
        let payload = DocumentRecoveryPayload(
            id: UUID(),
            filePath: "/tmp/note.swift",
            text: "hello",
            encoding: .utf8,
            lineEnding: .lf,
            isMixedLineEndings: false,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        try store.save(payload)
        #expect(try store.loadAll() == [payload])
        try store.remove(id: payload.id)
        #expect(try store.loadAll().isEmpty)
    }

    @Test func fileRecoveryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("nib-recovery-\(UUID().uuidString)", isDirectory: true)
        let store = try FileRecoveryStore(directory: directory)
        let payload = DocumentRecoveryPayload(
            id: UUID(),
            filePath: nil,
            text: "untitled",
            encoding: .utf8WithBOM,
            lineEnding: .crlf,
            isMixedLineEndings: true,
            updatedAt: Date(timeIntervalSince1970: 42)
        )
        try store.save(payload)
        let loaded = try store.loadAll()
        #expect(loaded == [payload])
        try store.removeAll()
        #expect(try store.loadAll().isEmpty)
        try? FileManager.default.removeItem(at: directory)
    }
}

struct ExternalChangePolicyTests {
    @Test func dirtyPromptsAndCleanReloads() {
        #expect(ExternalChangePolicy.action(isDirty: false) == .reload)
        #expect(ExternalChangePolicy.action(isDirty: true) == .prompt)
    }
}
