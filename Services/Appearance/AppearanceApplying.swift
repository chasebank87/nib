import Combine
import NibDomain

public protocol AppearanceApplying: AnyObject {
    func apply(_ preference: AppearancePreference)
}

@MainActor
public final class AppearanceController: ObservableObject {
    public static let preferenceKey = "appearance.preference"

    @Published public var preference: AppearancePreference {
        didSet {
            store.set(string: preference.rawValue, for: Self.preferenceKey)
            apply()
        }
    }

    private let store: SettingsStoring
    private let applier: AppearanceApplying

    public init(
        preference: AppearancePreference,
        store: SettingsStoring,
        applier: AppearanceApplying
    ) {
        self.preference = preference
        self.store = store
        self.applier = applier
    }

    public func apply() {
        applier.apply(preference)
    }

    public func cycle() {
        preference = preference.next
    }
}
