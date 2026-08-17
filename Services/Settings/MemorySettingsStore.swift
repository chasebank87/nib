public final class MemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private var values: [String: String] = [:]

    public init(values: [String: String] = [:]) {
        self.values = values
    }

    public func string(for key: String) -> String? {
        values[key]
    }

    public func set(string: String?, for key: String) {
        if let string {
            values[key] = string
        } else {
            values.removeValue(forKey: key)
        }
    }
}
