public enum AppearancePreference: String, CaseIterable, Equatable, Sendable {
    case system
    case light
    case dark

    public var next: AppearancePreference {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
