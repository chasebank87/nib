import Foundation
import NibDomain
import NibServices
import Testing

struct LanguageServerDetectorTests {
    @Test func findsPythonServerFromCatalogOnFakePath() {
        let bin = URL(fileURLWithPath: "/tmp/nib-lsp-bin", isDirectory: true)
        let pyright = bin.appendingPathComponent("pyright-langserver")
        let detector = PathLanguageServerDetector(
            pathDirectories: [bin],
            fileExists: { $0 == pyright },
            isExecutable: { $0 == pyright }
        )
        let launch = detector.launchConfiguration(for: "python")
        #expect(launch?.displayName == "Pyright")
        #expect(launch?.executable == pyright)
        #expect(launch?.arguments == ["--stdio"])
        #expect(detector.installedServer(for: "python") == pyright)
        #expect(detector.launchConfiguration(for: "zig") == nil)
    }

    @Test func prefersFirstMatchingCandidate() {
        let bin = URL(fileURLWithPath: "/opt/tools", isDirectory: true)
        let pylsp = bin.appendingPathComponent("pylsp")
        let detector = PathLanguageServerDetector(
            pathDirectories: [bin],
            fileExists: { $0.path.hasSuffix("pylsp") },
            isExecutable: { $0.path.hasSuffix("pylsp") }
        )
        let launch = detector.launchConfiguration(for: "python")
        #expect(launch?.displayName == "Pylsp")
        #expect(launch?.executable == pylsp)
    }

    @Test func typescriptServerCoversJavascript() {
        let bin = URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        let tsserver = bin.appendingPathComponent("typescript-language-server")
        let detector = PathLanguageServerDetector(
            pathDirectories: [bin],
            fileExists: { $0 == tsserver },
            isExecutable: { $0 == tsserver }
        )
        #expect(detector.launchConfiguration(for: "javascript")?.displayName == "TypeScript")
        #expect(detector.launchConfiguration(for: "typescript")?.arguments == ["--stdio"])
    }

    @Test func catalogListsPriorityLanguageCoverage() {
        let covered = Set(LanguageServerCatalog.candidates.flatMap(\.languageIDs))
        #expect(covered.contains("python"))
        #expect(covered.contains("typescript"))
        #expect(covered.contains("swift"))
        #expect(covered.contains("zig"))
    }
}
