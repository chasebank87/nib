import Foundation

/// Capability flags derived from file size and language (NIB-010).
public struct DocumentCapabilities: Equatable, Sendable {
    public var wrapLines: Bool
    public var liveHighlighting: Bool
    public var lineNumbers: Bool
    public var currentLineHighlight: Bool
    public var indentGuides: Bool
    public var languageServers: Bool

    public init(
        wrapLines: Bool = true,
        liveHighlighting: Bool = true,
        lineNumbers: Bool = true,
        currentLineHighlight: Bool = true,
        indentGuides: Bool = true,
        languageServers: Bool = true
    ) {
        self.wrapLines = wrapLines
        self.liveHighlighting = liveHighlighting
        self.lineNumbers = lineNumbers
        self.currentLineHighlight = currentLineHighlight
        self.indentGuides = indentGuides
        self.languageServers = languageServers
    }

    public static let full = DocumentCapabilities()

    public static func forByteCount(_ byteCount: Int) -> DocumentCapabilities {
        if byteCount >= DocumentLimits.hardWarningByteCount {
            return DocumentCapabilities(
                wrapLines: false,
                liveHighlighting: false,
                lineNumbers: false,
                currentLineHighlight: false,
                indentGuides: false,
                languageServers: false
            )
        }
        if DocumentLimits.isReducedFeature(byteCount) {
            return DocumentCapabilities(
                wrapLines: false,
                liveHighlighting: false,
                lineNumbers: true,
                currentLineHighlight: true,
                indentGuides: false,
                languageServers: false
            )
        }
        return .full
    }
}
