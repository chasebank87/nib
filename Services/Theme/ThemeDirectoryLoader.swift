import Foundation
import NibDomain

public enum ThemeDirectoryLoader {
    public static func load(from directory: URL) throws -> [Theme] {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try ThemeCodec.decode(Data(contentsOf: $0)) }
    }
}
