import Foundation
import NibCoreBridge
import NibDomain
import Testing

struct NibCoreTests {
    @Test func versionIsSemverLike() {
        let version = NibCore.version
        #expect(version.contains("."))
        #expect(version.isEmpty == false)
    }

    @Test func validatesASCIIAndEmpty() {
        #expect(NibCore.isValidUTF8(Data()))
        #expect(NibCore.isValidUTF8(Data("nib".utf8)))
        #expect(NibCore.isValidUTF8(Data("café".utf8)))
    }

    @Test func rejectsInvalidSequence() {
        #expect(NibCore.isValidUTF8(Data([0x80])) == false)
        #expect(throws: DocumentError.invalidUTF8) {
            try NibCore.validateUTF8(Data([0xFF, 0xFE]))
        }
    }

    @Test func actorSerializesTheSameContract() async throws {
        let core = NibCoreActor()
        #expect(await core.version() == NibCore.version)
        #expect(await core.isValidUTF8(Data("ok".utf8)))
        await #expect(throws: DocumentError.invalidUTF8) {
            try await core.validateUTF8(Data([0x80]))
        }
    }
}
