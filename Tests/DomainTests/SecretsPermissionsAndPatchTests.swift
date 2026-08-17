import Foundation
import NibDomain
import NibServices
import Testing

struct SecretStoreTests {
    @Test func inMemoryRoundTripAndDelete() throws {
        let store = InMemorySecretStore()
        let account = KeychainSecretStore.providerAPIKeyAccount
        let secret = Data("test-secret".utf8)
        try store.store(account: account, secret: secret)
        #expect(try store.retrieve(account: account) == secret)
        try store.delete(account: account)
        #expect(try store.retrieve(account: account) == nil)
    }
}

struct TextPatchApplierTests {
    @Test func replacesUTF16Range() throws {
        let text = "hello world"
        let updated = try TextPatchApplier.replaceUTF16Range(
            in: text,
            range: 6..<11,
            with: "nib"
        )
        #expect(updated == "hello nib")
    }

    @Test func rejectsOutOfBounds() {
        #expect(throws: TextPatchError.outOfBounds) {
            _ = try TextPatchApplier.replaceUTF16Range(in: "ab", range: 0..<5, with: "x")
        }
    }
}

struct ToolPermissionTests {
    @Test @MainActor func promptGrantAddsPermission() throws {
        let controller = ToolPermissionController(grants: [.readCurrentFile])
        #expect(controller.has(.applyEdits) == false)
        try controller.require(.applyEdits, allowPromptGrant: true)
        #expect(controller.has(.applyEdits))
    }

    @Test @MainActor func deniedWithoutPrompt() {
        let controller = ToolPermissionController(grants: [])
        #expect(throws: AIProviderError.permissionDenied(.sendToProvider)) {
            try controller.require(.sendToProvider, allowPromptGrant: false)
        }
    }
}

struct MockAIEditTests {
    @Test func editInstructionProducesProposedEdit() async throws {
        let provider = MockAIProvider()
        let response = try await provider.complete(
            AIRequest(
                instruction: "Edit this selection",
                selectedText: "print(1)",
                disclosure: ContextDisclosure(selectedCharacterCount: 8)
            )
        )
        #expect(response.proposedEdit?.contains("mock-improved") == true)
    }

    @Test func documentInstructionProducesDocComment() async throws {
        let provider = MockAIProvider()
        let response = try await provider.complete(
            AIRequest(
                instruction: "Document this selection",
                selectedText: "def hello():\n    pass\n",
                disclosure: ContextDisclosure(selectedCharacterCount: 20)
            )
        )
        #expect(response.proposedEdit?.hasPrefix("/// Mock documentation") == true)
    }
}
