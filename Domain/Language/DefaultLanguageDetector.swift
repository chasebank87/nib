import Foundation

public struct DefaultLanguageDetector: LanguageDetecting {
    public var languages: [LanguageDescriptor]

    public init(languages: [LanguageDescriptor] = LanguageDescriptor.priorityLanguages) {
        self.languages = languages
    }

    public func detect(
        url: URL?,
        firstLine: String?,
        content: String?,
        overrideID: String?
    ) -> LanguageDescriptor {
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
        if let content, let match = detectFromContent(content) {
            return match
        }
        return .plainText
    }

    /// Lightweight heuristics for untitled buffers and extensionless files.
    private func detectFromContent(_ content: String) -> LanguageDescriptor? {
        let sample = String(content.prefix(4096))
        guard sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        let checks: [(id: String, pattern: String)] = [
            ("dockerfile", #"(?m)^(?i:FROM)\s+\S+"#),
            ("python", #"(?m)^\s*(async\s+def|def|class|from\s+\w+(\.\w+)*\s+import|import\s+\w+)\b"#),
            ("swift", #"(?m)^\s*(import\s+\w+|@main|func\s+\w+|struct\s+\w+|class\s+\w+|enum\s+\w+)\b"#),
            ("zig", #"(?m)^\s*(const\s+\w+\s*=\s*@import|pub\s+fn\s+\w+|fn\s+\w+)\b"#),
            ("typescript", #"(?m)^\s*(import\s+type\s+|export\s+(type|interface|default)|interface\s+\w+|type\s+\w+\s*=)"#),
            ("javascript", #"(?m)^\s*(import\s+.+from\s+|export\s+(default\s+)?(function|class|const|let|var)|const\s+\w+\s*=\s*require\()"#),
            ("json", #"^\s*[\{\[]"#),
            ("yaml", #"(?m)^---\s*$|^\w[\w-]*:\s"#),
            ("markdown", #"(?m)^#{1,6}\s+\S|^\s*```"#),
            ("sql", #"(?m)^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b"#),
            ("shell", #"(?m)^\s*(#!.*(bash|zsh|sh)\b|export\s+\w+=)"#),
        ]

        for check in checks {
            if sample.range(of: check.pattern, options: .regularExpression) != nil,
               let language = languages.first(where: { $0.id == check.id })
            {
                return language
            }
        }
        return nil
    }
}
