import Foundation
import NibDomain

/// Owns the active language-server client (real PATH auto-detect, demo FakeLSP, or off).
@MainActor
public final class LanguageServerController: ObservableObject {
    public enum Mode: Equatable, Sendable {
        case off
        case demo
        case auto
    }

    @Published public private(set) var diagnostics: [Diagnostic] = []
    @Published public private(set) var statusMessage: String = "LSP off"
    /// Bumped whenever the underlying client is replaced so documents re-open.
    @Published public private(set) var generation: Int = 0
    @Published public private(set) var mode: Mode = .off
    @Published public private(set) var activeLanguageID: String?

    public private(set) var client: any LanguageServerClienting
    public let detector: LanguageServerInstalling

    private var fakeServer: FakeLSPServer?
    private var serverTask: Task<Void, Never>?
    private var diagnosticsTask: Task<Void, Never>?
    private var processTransport: ProcessLSPTransport?
    private var desiredMode: Mode = .off
    private var runningLanguageID: String?

    public init(
        client: any LanguageServerClienting = UnconfiguredLanguageServer(),
        detector: LanguageServerInstalling = PathLanguageServerDetector()
    ) {
        self.client = client
        self.detector = detector
    }

    public func applySettings(_ settings: EditorSettings) async {
        let next: Mode
        if settings.enableLanguageServer == false {
            next = .off
        } else if settings.enableDemoLanguageServer {
            next = .demo
        } else {
            next = .auto
        }
        desiredMode = next
        if next == .off {
            await shutdownCurrent()
            client = UnconfiguredLanguageServer()
            generation += 1
            diagnostics = []
            statusMessage = "LSP off"
            mode = .off
            activeLanguageID = nil
            return
        }
        if next == .demo {
            await startDemo()
            return
        }
        // Auto: (re)activate for the current language if we already have one.
        if let languageID = activeLanguageID {
            await activate(for: languageID)
        } else {
            mode = .auto
            statusMessage = "LSP auto"
            if fakeServer != nil || processTransport != nil {
                await shutdownCurrent()
                client = UnconfiguredLanguageServer()
                generation += 1
                diagnostics = []
            }
        }
    }

    /// Ensures a client is running for `languageID` (auto-detect on PATH, or demo).
    public func activate(for languageID: String) async {
        activeLanguageID = languageID
        switch desiredMode {
        case .off:
            return
        case .demo:
            await startDemo()
        case .auto:
            await startAuto(for: languageID)
        }
    }

    private func startDemo() async {
        if mode == .demo, fakeServer != nil { return }
        await shutdownCurrent()
        let pair = await DemoLanguageServerFactory.make()
        fakeServer = pair.server
        client = pair.client
        generation += 1
        mode = .demo
        serverTask = Task { await pair.server.run() }
        do {
            try await pair.client.start()
            statusMessage = "Demo LSP"
            attachDiagnostics(from: pair.client)
        } catch {
            statusMessage = "LSP failed to start"
            AppLog.lsp.error("demo LSP start failed \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startAuto(for languageID: String) async {
        if mode == .auto,
           runningLanguageID == languageID,
           processTransport != nil
        {
            return
        }
        // Switching languages: tear down the previous real server.
        await shutdownCurrent()
        mode = .auto
        guard let launch = detector.launchConfiguration(for: languageID) else {
            client = UnconfiguredLanguageServer()
            generation += 1
            diagnostics = []
            runningLanguageID = languageID
            statusMessage = "No LSP for \(displayName(for: languageID))"
            return
        }
        do {
            let transport = try await ProcessLSPTransport.launch(
                executable: launch.executable,
                arguments: launch.arguments
            )
            processTransport = transport
            let lspClient = LSPClient(transport: transport)
            client = lspClient
            generation += 1
            runningLanguageID = languageID
            try await lspClient.start()
            statusMessage = launch.displayName
            attachDiagnostics(from: lspClient)
            AppLog.lsp.info(
                "started \(launch.displayName, privacy: .public) for \(languageID, privacy: .public)"
            )
        } catch {
            client = UnconfiguredLanguageServer()
            generation += 1
            diagnostics = []
            runningLanguageID = nil
            statusMessage = "LSP failed (\(launch.displayName))"
            AppLog.lsp.error(
                "real LSP start failed \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func attachDiagnostics(from client: LSPClient) {
        diagnosticsTask?.cancel()
        diagnosticsTask = Task { [weak self] in
            let stream = await client.diagnosticsUpdates
            for await update in stream {
                await MainActor.run {
                    self?.diagnostics = update
                }
            }
        }
    }

    public func shutdownCurrent() async {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        await client.stop()
        await fakeServer?.stop()
        await processTransport?.close()
        serverTask?.cancel()
        serverTask = nil
        fakeServer = nil
        processTransport = nil
        runningLanguageID = nil
    }

    private func displayName(for languageID: String) -> String {
        LanguageDescriptor.priorityLanguages.first(where: { $0.id == languageID })?.name
            ?? languageID
    }
}
