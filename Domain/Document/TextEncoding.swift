public enum TextEncoding: String, Equatable, Sendable, CaseIterable {
    case utf8

    /// TODO(NIB-001): Expand with UTF-16, Latin-1, and an explicit conversion path.
    public var displayName: String {
        switch self {
        case .utf8:
            "UTF-8"
        }
    }
}
