import NibDomain
import Testing

struct CommandRegistryTests {
    @Test func commandFilterFuzzyAndLiteral() {
        let command = EditorCommand(
            id: BuiltInCommandID.toggleAppearance,
            title: "Toggle Appearance",
            keywords: ["theme"]
        )
        #expect(CommandFilter.matches(command, query: ""))
        #expect(CommandFilter.matches(command, query: "app"))
        #expect(CommandFilter.matches(command, query: "tapp"))
        #expect(CommandFilter.matches(command, query: "theme"))
        #expect(CommandFilter.matches(command, query: "xyz") == false)
    }

    @Test func emptyQueryPreservesRegistrationOrder() {
        let first = EditorCommand(id: "a", title: "Alpha")
        let second = EditorCommand(id: "b", title: "Beta")
        #expect(CommandFilter.ranked([second, first], query: "") == [second, first])
        #expect(CommandFilter.ranked([first, second], query: "al") == [first])
    }

    @Test func registryHidesDisabledAndRunsEnabled() {
        let registry = CommandRegistry()
        var ran = ""
        var saveEnabled = false
        registry.register(EditorCommand(id: "file.save", title: "Save"), isEnabled: { saveEnabled }) {
            ran = "save"
        }
        registry.register(EditorCommand(id: "file.open", title: "Open")) {
            ran = "open"
        }
        #expect(registry.visibleCommands().map(\.id) == ["file.open"])
        registry.perform("file.save")
        #expect(ran == "")
        saveEnabled = true
        #expect(registry.visibleCommands().map(\.id) == ["file.save", "file.open"])
        registry.perform("file.save")
        #expect(ran == "save")
    }
}
