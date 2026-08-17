import Foundation
import NibServices
import Testing

struct GitFileMarkTests {
    @Test func parsesPorcelainMarks() {
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: " M a.swift") == .modified)
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: "M  a.swift") == .staged)
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: "?? a.swift") == .untracked)
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: "MM a.swift") == .modified)
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: "") == .clean)
        #expect(GitStatusReader.mark(for: "/tmp/a.swift", porcelain: " M ba.swift") == .clean)
        #expect(GitStatusReader.mark(for: "/tmp/ba.swift", porcelain: " M a.swift") == .clean)
        #expect(GitStatusReader.mark(for: "/repo/src/a.swift", porcelain: " M src/a.swift") == .modified)
    }
}
