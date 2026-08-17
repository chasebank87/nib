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
}
