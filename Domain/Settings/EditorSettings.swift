public struct EditorSettings: Equatable, Sendable, Codable {
    public var fontName: String
    public var fontSize: Double
    public var lineHeight: Double
    public var tabWidth: Int
    public var insertSpaces: Bool
    public var wrapLines: Bool
    public var ligatures: Bool

    public init(
        fontName: String = ".AppleSystemUIFontMonospaced",
        fontSize: Double = 13,
        lineHeight: Double = 1.35,
        tabWidth: Int = 4,
        insertSpaces: Bool = true,
        wrapLines: Bool = false,
        ligatures: Bool = true
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.tabWidth = tabWidth
        self.insertSpaces = insertSpaces
        self.wrapLines = wrapLines
        self.ligatures = ligatures
    }

    public static let `default` = EditorSettings()
}
