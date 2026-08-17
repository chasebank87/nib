import Foundation
import NibDomain

/// Builds and advances a visible agent plan. No silent writes.
@MainActor
public final class AgentOrchestrator {
    public init() {}

    public func makeImproveSelectionPlan(
        selection: String,
        selectionRange: Range<Int>,
        diagnostics: [Diagnostic],
        filePath: String?,
        includeGit: Bool = true,
        includeWorkspaceSearch: Bool = false,
        searchQuery: String? = nil
    ) -> AgentPlan {
        var steps: [AgentPlanStep] = [
            AgentPlanStep(
                title: "Read selection",
                detail: "\(selection.count) characters",
                toolCall: AgentToolCall(
                    toolName: "read_selection",
                    argumentsDescription: "current selection",
                    requiredPermission: .readCurrentFile
                )
            ),
        ]
        if diagnostics.isEmpty == false {
            steps.append(
                AgentPlanStep(
                    title: "Read diagnostics",
                    detail: "\(diagnostics.count) issues",
                    toolCall: AgentToolCall(
                        toolName: "read_diagnostics",
                        argumentsDescription: "open-file diagnostics",
                        requiredPermission: .readDiagnostics
                    )
                )
            )
        }
        if includeGit, filePath != nil {
            steps.append(
                AgentPlanStep(
                    title: "Inspect Git status",
                    detail: "read-only",
                    toolCall: AgentToolCall(
                        toolName: "git_status",
                        argumentsDescription: filePath ?? "",
                        requiredPermission: .inspectGit
                    )
                )
            )
        }
        if includeWorkspaceSearch, let query = searchQuery, query.isEmpty == false {
            steps.append(
                AgentPlanStep(
                    title: "Search workspace",
                    detail: query,
                    toolCall: AgentToolCall(
                        toolName: "search_workspace",
                        argumentsDescription: query,
                        requiredPermission: .searchWorkspace
                    )
                )
            )
        }
        steps.append(
            AgentPlanStep(
                title: "Propose edit",
                detail: filePath.map { "via provider for \($0)" } ?? "via provider",
                toolCall: AgentToolCall(
                    toolName: "complete",
                    argumentsDescription: "edit selection",
                    requiredPermission: .sendToProvider
                )
            )
        )
        steps.append(
            AgentPlanStep(
                title: "Review and apply",
                detail: "requires explicit Apply",
                toolCall: AgentToolCall(
                    toolName: "apply_patch",
                    argumentsDescription: "selection replace",
                    requiredPermission: .applyEdits
                )
            )
        )
        return AgentPlan(
            goal: "Improve selection",
            steps: steps,
            selectionRange: selectionRange
        )
    }

    public func run(
        plan: AgentPlan,
        selection: String,
        diagnostics: [Diagnostic],
        filePath: String?,
        permissions: ToolPermissionController,
        provider: AIProvider,
        allowPromptGrant: Bool
    ) async -> AgentPlan {
        var working = plan
        let diagnosticsText = diagnostics
            .map { "L\($0.line):\($0.column) \($0.severity.rawValue): \($0.message)" }
            .joined(separator: "\n")
        var gitContext = ""
        var searchContext = ""

        for index in working.steps.indices {
            working.steps[index].status = .running
            guard let tool = working.steps[index].toolCall else {
                working.steps[index].status = .completed
                continue
            }

            do {
                if permissions.has(tool.requiredPermission) == false {
                    working.steps[index].status = .waitingPermission
                }
                try permissions.require(tool.requiredPermission, allowPromptGrant: allowPromptGrant)

                switch tool.toolName {
                case "read_selection":
                    working.steps[index].detail = String(selection.prefix(120))
                    working.steps[index].status = .completed
                case "read_diagnostics":
                    working.steps[index].detail = diagnosticsText.isEmpty ? "none" : diagnosticsText
                    working.steps[index].status = .completed
                case "git_status":
                    let snapshot = try GitStatusReader.snapshot(startingAt: filePath)
                    gitContext = snapshot.summary
                    working.steps[index].detail = String(gitContext.prefix(240))
                    working.steps[index].status = .completed
                case "search_workspace":
                    let hits = try WorkspaceFileSearch.search(
                        query: tool.argumentsDescription,
                        startingAt: filePath
                    )
                    searchContext = hits.map(\.path).joined(separator: "\n")
                    working.steps[index].detail = hits.isEmpty
                        ? "no matches"
                        : "\(hits.count) files"
                    working.steps[index].status = .completed
                case "complete":
                    var fileText: String?
                    if gitContext.isEmpty == false || searchContext.isEmpty == false {
                        fileText = [
                            gitContext.isEmpty ? nil : "Git:\n\(gitContext)",
                            searchContext.isEmpty ? nil : "Workspace hits:\n\(searchContext)",
                        ]
                        .compactMap { $0 }
                        .joined(separator: "\n\n")
                    }
                    let disclosure = ContextDisclosure(
                        filePath: filePath,
                        selectedCharacterCount: selection.count,
                        includesDiagnostics: diagnostics.isEmpty == false,
                        includesRepositoryContext: gitContext.isEmpty == false,
                        includesCommandOutput: false
                    )
                    let response = try await provider.complete(
                        AIRequest(
                            instruction: "Edit this selection",
                            selectedText: selection,
                            fileText: fileText,
                            diagnosticsText: diagnosticsText.isEmpty ? nil : diagnosticsText,
                            disclosure: disclosure
                        )
                    )
                    working.proposedEdit = response.proposedEdit ?? selection
                    working.summary = response.text
                    working.steps[index].detail = "proposal ready"
                    working.steps[index].status = .completed
                case "apply_patch":
                    working.steps[index].status = .pending
                    working.steps[index].detail = "waiting for Apply"
                default:
                    working.steps[index].status = .skipped
                }
            } catch AIProviderError.permissionDenied {
                working.steps[index].status = .failed
                working.steps[index].detail = "permission denied"
                markRemainingSkipped(&working, after: index)
                working.summary = "Stopped: permission denied for \(tool.toolName)."
                return working
            } catch {
                working.steps[index].status = .failed
                working.steps[index].detail = error.localizedDescription
                markRemainingSkipped(&working, after: index)
                working.summary = "Stopped: \(error.localizedDescription)"
                return working
            }
        }
        if working.summary == nil {
            working.summary = "Plan finished. Review the proposed edit before applying."
        }
        return working
    }

    private func markRemainingSkipped(_ plan: inout AgentPlan, after index: Int) {
        let next = index + 1
        guard next < plan.steps.count else { return }
        for i in next..<plan.steps.count {
            if plan.steps[i].status == .pending {
                plan.steps[i].status = .skipped
            }
        }
    }
}
