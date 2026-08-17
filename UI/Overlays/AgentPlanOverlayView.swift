import NibDomain
import SwiftUI

/// Visible agent plan with tool steps and gated apply.
public struct AgentPlanOverlayView: View {
    var plan: AgentPlan
    var theme: Theme
    var isRunning: Bool
    var onRun: () -> Void
    var onApply: (() -> Void)?
    var onDismiss: () -> Void

    public init(
        plan: AgentPlan,
        theme: Theme,
        isRunning: Bool = false,
        onRun: @escaping () -> Void,
        onApply: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.plan = plan
        self.theme = theme
        self.isRunning = isRunning
        self.onRun = onRun
        self.onApply = onApply
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(plan.goal)
                        .font(.headline)
                        .foregroundStyle(theme.color(.overlayForeground))
                    Spacer()
                    Button("Esc", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
                if let summary = plan.summary {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.color(.overlayForeground).opacity(0.85))
                        .textSelection(.enabled)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.steps) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Text(statusLabel(step.status))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(statusColor(step.status))
                                    .frame(width: 72, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(theme.color(.overlayForeground))
                                    if step.detail.isEmpty == false {
                                        Text(step.detail)
                                            .font(.system(size: 11))
                                            .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                                            .lineLimit(3)
                                    }
                                    if let tool = step.toolCall {
                                        Text("tool: \(tool.toolName)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(theme.color(.overlayForeground).opacity(0.55))
                                    }
                                }
                            }
                        }
                        if let proposed = plan.proposedEdit {
                            Text("Proposed edit")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.color(.overlayForeground).opacity(0.75))
                                .padding(.top, 4)
                            Text(proposed)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.color(.overlayForeground))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(theme.color(.gutterBackground).opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .textSelection(.enabled)
                        }
                    }
                }
                HStack {
                    Button("Cancel", action: onDismiss)
                    Spacer()
                    if plan.proposedEdit != nil, let onApply {
                        Button("Apply", action: onApply)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button(isRunning ? "Running…" : "Run Plan", action: onRun)
                            .disabled(isRunning)
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(16)
            .frame(width: 500, height: 380)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    private func statusLabel(_ status: AgentStepStatus) -> String {
        switch status {
        case .pending: return "pending"
        case .running: return "running"
        case .waitingPermission: return "grant?"
        case .completed: return "done"
        case .failed: return "failed"
        case .skipped: return "skip"
        }
    }

    private func statusColor(_ status: AgentStepStatus) -> Color {
        switch status {
        case .pending: return theme.color(.overlayForeground).opacity(0.55)
        case .running, .waitingPermission: return theme.color(.diagnosticWarning)
        case .completed: return theme.color(.diagnosticInfo)
        case .failed: return theme.color(.diagnosticError)
        case .skipped: return theme.color(.overlayForeground).opacity(0.4)
        }
    }
}
