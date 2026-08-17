import Foundation
import NibDomain

/// Resolves language servers from PATH using `LanguageServerCatalog`.
public struct PathLanguageServerDetector: LanguageServerInstalling, Sendable {
    public var pathDirectories: [URL]
    public var fileExists: @Sendable (URL) -> Bool
    public var isExecutable: @Sendable (URL) -> Bool

    public init(
        pathDirectories: [URL]? = nil,
        fileExists: @escaping @Sendable (URL) -> Bool = { url in
            FileManager.default.fileExists(atPath: url.path)
        },
        isExecutable: @escaping @Sendable (URL) -> Bool = { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    ) {
        if let pathDirectories {
            self.pathDirectories = pathDirectories
        } else {
            self.pathDirectories = Self.defaultPathDirectories()
        }
        self.fileExists = fileExists
        self.isExecutable = isExecutable
    }

    public func installedServer(for languageID: String) -> URL? {
        launchConfiguration(for: languageID)?.executable
    }

    public func launchConfiguration(for languageID: String) -> LanguageServerLaunch? {
        for candidate in LanguageServerCatalog.candidates(for: languageID) {
            for name in candidate.executableNames {
                if let url = resolveExecutable(named: name) {
                    return LanguageServerLaunch(
                        languageID: languageID,
                        displayName: candidate.displayName,
                        executable: url,
                        arguments: candidate.arguments
                    )
                }
            }
        }
        return nil
    }

    /// Lists every catalog language that currently has a server on PATH.
    public func availableLanguageIDs() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for candidate in LanguageServerCatalog.candidates {
            for languageID in candidate.languageIDs where seen.insert(languageID).inserted {
                if launchConfiguration(for: languageID) != nil {
                    result.append(languageID)
                }
            }
        }
        return result
    }

    private func resolveExecutable(named name: String) -> URL? {
        if name.contains("/") {
            let url = URL(fileURLWithPath: name)
            return isPresentExecutable(url) ? url : nil
        }
        for directory in pathDirectories {
            let url = directory.appendingPathComponent(name)
            if isPresentExecutable(url) {
                return url
            }
        }
        return nil
    }

    private func isPresentExecutable(_ url: URL) -> Bool {
        fileExists(url) && isExecutable(url)
    }

    public static func defaultPathDirectories() -> [URL] {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var directories = path
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true) }

        // Common Mac install locations even when GUI apps inherit a minimal PATH.
        let extras = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.cargo/bin",
            "\(NSHomeDirectory())/go/bin",
        ].map { URL(fileURLWithPath: $0, isDirectory: true) }

        for extra in extras where directories.contains(extra) == false {
            directories.append(extra)
        }
        return directories
    }
}
