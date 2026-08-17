import SwiftUI

public struct SettingsPlaceholderView: View {
    public init() {}

    public var body: some View {
        Form {
            Text("Editor settings land in NIB-004. Appearance is available from the command palette.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 160)
    }
}
