public struct TextDocumentModel: Equatable, Sendable {
    public var text: String
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var isDirty: Bool

    public init(
        text: String = "",
        encoding: TextEncoding = .utf8,
        lineEnding: LineEnding = .lf,
        isDirty: Bool = false
    ) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
    }

    public mutating func replaceText(_ newText: String) {
        guard text != newText else { return }
        text = newText
        isDirty = true
    }

    public mutating func markSaved() {
        isDirty = false
    }
}

/// TODO(NIB-010): Honor these thresholds when opening files and configuring services.
public enum DocumentLimits {
    public static let reducedFeatureByteCount = 2 * 1024 * 1024
    public static let hardWarningByteCount = 32 * 1024 * 1024
}
