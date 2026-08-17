import Foundation
import NibDomain
import Testing

struct ThemeTests {
    @Test func builtinThemesCoverEveryToken() {
        for theme in Theme.builtIn {
            for token in ThemeToken.allCases {
                let hex = theme.hex(for: token)
                #expect(hex.hasPrefix("#"))
                #expect(hex.count == 7 || hex.count == 9)
            }
        }
    }

    @Test func shippedJSONMatchesBuiltins() throws {
        let light = try loadTheme(named: "nib-light")
        let dark = try loadTheme(named: "nib-dark")
        #expect(light.id == Theme.nibLight.id)
        #expect(dark.id == Theme.nibDark.id)
        #expect(light.tokens == Theme.nibLight.tokens)
        #expect(dark.tokens == Theme.nibDark.tokens)
        #expect(light.syntax == Theme.nibLight.syntax)
        #expect(dark.syntax == Theme.nibDark.syntax)
    }

    @Test func syntaxScopeMapsToToken() {
        #expect(Theme.nibDark.token(forSyntaxScope: "keyword") == .syntaxKeyword)
        #expect(Theme.nibLight.token(forSyntaxScope: "missing") == nil)
    }

    private func loadTheme(named name: String) throws -> Theme {
        let url = repoRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("Themes")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try ThemeCodec.decode(data)
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
