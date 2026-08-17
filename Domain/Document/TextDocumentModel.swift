import Foundation

public struct TextDocumentModel: Equatable, Sendable {
    public var text: String
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var isDirty: Bool
    public var isMixedLineEndings: Bool
    public var originalBytes: Data?
    public var byteCount: Int
    public var isReducedFeature: Bool

    public init(
        text: String = "",
        encoding: TextEncoding = .utf8,
        lineEnding: LineEnding = .lf,
        isDirty: Bool = false,
        isMixedLineEndings: Bool = false,
        originalBytes: Data? = nil,
        byteCount: Int = 0,
        isReducedFeature: Bool = false
    ) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
        self.isMixedLineEndings = isMixedLineEndings
        self.originalBytes = originalBytes
        self.byteCount = byteCount
        self.isReducedFeature = isReducedFeature
    }

    public mutating func replaceText(_ newText: String) {
        guard text != newText else { return }
        text = newText
        isDirty = true
        originalBytes = nil
    }

    public mutating func markSaved() {
        isDirty = false
    }
}

/// Thresholds for open warnings and crude reduced-feature mode (NIB-010 lite).
public enum DocumentLimits {
    public static let reducedFeatureByteCount = 2 * 1024 * 1024
    public static let hardWarningByteCount = 32 * 1024 * 1024

    public static func isReducedFeature(_ byteCount: Int) -> Bool {
        byteCount >= reducedFeatureByteCount
    }

    public static func needsOpenWarning(_ byteCount: Int) -> Bool {
        byteCount >= reducedFeatureByteCount
    }
}
