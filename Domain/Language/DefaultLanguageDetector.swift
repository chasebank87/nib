import Foundation

public struct DefaultLanguageDetector: LanguageDetecting {
    public var languages: [LanguageDescriptor]

    public init(languages: [LanguageDescriptor] = LanguageDescriptor.priorityLanguages) {
        self.languages = languages
    }

    public func detect(url: URL?, firstLine: String?, overrideID: String?) -> LanguageDescriptor {
        if let overrideID {
            if overrideID == LanguageDescriptor.plainText.id {
                return .plainText
            }
            if let match = languages.first(where: { $0.id == overrideID }) {
                return match
            }
        }
        if let url {
            let filename = url.lastPathComponent
            if let match = languages.first(where: { $0.filenames.contains(filename) }) {
                return match
            }
            let ext = url.pathExtension.lowercased()
            if ext.isEmpty == false, let match = languages.first(where: { $0.extensions.contains(ext) }) {
                return match
            }
        }
        if let firstLine, firstLine.hasPrefix("#!") {
            let shebang = firstLine.dropFirst(2)
            if let match = languages.first(where: { language in
                language.shebangs.contains { shebang.contains($0) }
            }) {
                return match
            }
        }
        return .plainText
    }
}
