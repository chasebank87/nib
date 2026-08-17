import Foundation
import NibDomain

public final class ThemeCatalog: @unchecked Sendable {
    public private(set) var themes: [Theme]

    public init(builtIn: [Theme] = Theme.builtIn, extra: [Theme] = []) {
        var merged = builtIn
        for theme in extra where merged.contains(where: { $0.id == theme.id }) == false {
            merged.append(theme)
        }
        self.themes = merged
    }

    public func theme(id: String) -> Theme? {
        themes.first { $0.id == id }
    }

    public static func loadUserThemes(from directory: URL = ThemeCatalog.defaultUserDirectory) -> [Theme] {
        (try? ThemeDirectoryLoader.load(from: directory)) ?? []
    }

    public static var defaultUserDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("com.chaseelder.nib", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }

    public static func ensureUserDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: defaultUserDirectory,
            withIntermediateDirectories: true
        )
    }
}
