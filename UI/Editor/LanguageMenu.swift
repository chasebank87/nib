import NibDomain
import SwiftUI

/// Status-bar language control. Choosing an entry sets a document override;
/// “Detect Automatically” clears it.
public struct LanguageMenu: View {
    var language: LanguageDescriptor
    var theme: Theme
    var onSelect: (String?) -> Void

    private var choices: [LanguageDescriptor] {
        LanguageDescriptor.priorityLanguages + [.plainText]
    }

    public init(
        language: LanguageDescriptor,
        theme: Theme,
        onSelect: @escaping (String?) -> Void
    ) {
        self.language = language
        self.theme = theme
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            Button("Detect Automatically") {
                onSelect(nil)
            }
            Divider()
            ForEach(choices) { choice in
                Button {
                    onSelect(choice.id)
                } label: {
                    if choice.id == language.id {
                        Label(choice.name, systemImage: "checkmark")
                    } else {
                        Text(choice.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                Text(language.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(theme.color(.gutterForeground))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Set language for highlighting and LSP")
        .accessibilityLabel("Language \(language.name)")
    }
}
