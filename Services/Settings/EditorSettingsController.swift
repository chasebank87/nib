import Combine
import Foundation
import NibDomain

@MainActor
public final class EditorSettingsController: ObservableObject {
    @Published public var settings: EditorSettings {
        didSet {
            persist()
            NotificationCenter.default.post(name: .nibEditorSettingsDidChange, object: nil)
        }
    }

    private let store: SettingsStoring

    public init(store: SettingsStoring) {
        self.store = store
        settings = EditorSettings.decoded(from: store.string(for: EditorSettings.storageKey))
    }

    private func persist() {
        store.set(string: settings.encodedJSON(), for: EditorSettings.storageKey)
    }
}
