import Foundation
import NibDomain
import Testing

struct LanguageDetectorTests {
    private let detector = DefaultLanguageDetector()

    @Test func extensionAndOverride() {
        let zig = detector.detect(url: URL(fileURLWithPath: "/tmp/core.zig"), firstLine: nil, overrideID: nil)
        #expect(zig.id == "zig")
        let forced = detector.detect(
            url: URL(fileURLWithPath: "/tmp/core.zig"),
            firstLine: nil,
            overrideID: "python"
        )
        #expect(forced.id == "python")
    }

    @Test func shebangAndUnknown() {
        let python = detector.detect(
            url: URL(fileURLWithPath: "/usr/local/bin/tool"),
            firstLine: "#!/usr/bin/env python3",
            overrideID: nil
        )
        #expect(python.id == "python")
        let unknown = detector.detect(
            url: URL(fileURLWithPath: "/tmp/notes.unknown"),
            firstLine: "hello",
            overrideID: nil
        )
        #expect(unknown == .plainText)
    }

    @Test func filenameRules() {
        let manifest = detector.detect(
            url: URL(fileURLWithPath: "/tmp/Package.swift"),
            firstLine: nil,
            overrideID: nil
        )
        #expect(manifest.id == "swift")
        let docker = detector.detect(
            url: URL(fileURLWithPath: "/tmp/Dockerfile"),
            firstLine: nil,
            overrideID: nil
        )
        #expect(docker.id == "dockerfile")
    }

    @Test func contentHeuristicsForUntitledBuffers() {
        let python = detector.detect(
            url: nil,
            firstLine: "def hello_world():",
            content: "def hello_world():\n    print(\"hello\")\n",
            overrideID: nil
        )
        #expect(python.id == "python")

        let swift = detector.detect(
            url: nil,
            firstLine: "import Foundation",
            content: "import Foundation\n\nfunc main() {}\n",
            overrideID: nil
        )
        #expect(swift.id == "swift")

        let json = detector.detect(
            url: nil,
            firstLine: "{",
            content: "{\n  \"ok\": true\n}\n",
            overrideID: nil
        )
        #expect(json.id == "json")

        let empty = detector.detect(url: nil, firstLine: nil, content: "   \n", overrideID: nil)
        #expect(empty == .plainText)
    }

    @Test func extensionWinsOverContentHeuristics() {
        let zig = detector.detect(
            url: URL(fileURLWithPath: "/tmp/core.zig"),
            firstLine: "def not_python():",
            content: "def not_python():\n    pass\n",
            overrideID: nil
        )
        #expect(zig.id == "zig")
    }
}
