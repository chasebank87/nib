import Foundation
import NibDomain

/// Owns the active language-server client (demo FakeLSP or unconfigured).
@MainActor
public final class LanguageServerController: ObservableObject {
    @Published public private(set) var diagnostics: [Diagnostic] = []
    @Published public private(set) var statusMessage: String = "LSP off"
    /// Bumped whenever the underlying client is replaced so documents re-open.
    @Published public private(set) var generation: Int = 0

    public private(set) var client: any LanguageServerClienting
    private var fakeServer: FakeLSPServer?
    private var serverTask: Task<Void, Never>?
    private var diagnosticsTask: Task<Void, Never>?
    private var demoEnabled = false

    public init(client: any LanguageServerClienting = UnconfiguredLanguageServer()) {
        self.client = client
    }

    public func applySettings(_ settings: EditorSettings) async {
        await setDemoEnabled(settings.enableDemoLanguageServer)
    }

    public func setDemoEnabled(_ enabled: Bool) async {
        guard enabled != demoEnabled || (enabled && fakeServer == nil) else { return }
        demoEnabled = enabled
        await shutdownCurrent()
        if enabled {
            let pair = await DemoLanguageServerFactory.make()
            fakeServer = pair.server
            client = pair.client
            generation += 1
            serverTask = Task { await pair.server.run() }
            do {
                try await pair.client.start()
                statusMessage = "Demo LSP"
                diagnosticsTask = Task { [weak self] in
                    for await update in pair.client.diagnosticsUpdates {
                        await MainActor.run {
                            self?.diagnostics = update
                        }
                    }
                }
            } catch {
                statusMessage = "LSP failed to start"
                AppLog.lsp.error("demo LSP start failed \(error.localizedDescription, privacy: .public)")
            }
        } else {
            client = UnconfiguredLanguageServer()
            generation += 1
            diagnostics = []
            statusMessage = "LSP off"
        }
    }

    public func shutdownCurrent() async {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        await client.stop()
        await fakeServer?.stop()
        serverTask?.cancel()
        serverTask = nil
        fakeServer = nil
    }
}
