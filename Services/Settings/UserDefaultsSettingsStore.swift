import Foundation

public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func string(for key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func set(string: String?, for key: String) {
        if let string {
            defaults.set(string, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
