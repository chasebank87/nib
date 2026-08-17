import NibDomain
import SwiftUI

/// Confirms and runs a one-shot shell command after permission grant.
public struct ApprovedCommandOverlayView: View {
    @Binding var command: String
    var workingDirectory: String?
    var theme: Theme
    var onRun: (String) -> Void
    var onDismiss: () -> Void

    public init(
        command: Binding<String>,
        workingDirectory: String?,
        theme: Theme,
        onRun: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _command = command
        self.workingDirectory = workingDirectory
        self.theme = theme
        self.onRun = onRun
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(alignment: .leading, spacing: 12) {
                Text("Run Approved Command")
                    .font(.headline)
                    .foregroundStyle(theme.color(.overlayForeground))
                Text("This runs once in a shell after you confirm. Nothing runs until you press Run.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.color(.overlayForeground).opacity(0.8))
                if let workingDirectory, workingDirectory.isEmpty == false {
                    Text("cwd: \(workingDirectory)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.color(.overlayForeground).opacity(0.7))
                        .lineLimit(2)
                }
                TextField("Command", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                HStack {
                    Button("Cancel", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Run") {
                        onRun(command)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 480)
            .background(theme.color(.overlayBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.color(.overlayBorder), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }
}
