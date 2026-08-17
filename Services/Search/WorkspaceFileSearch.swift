import Foundation
import NibDomain

public struct WorkspaceSearchHit: Equatable, Sendable, Identifiable {
    public var id: String { path }
    public var path: String
    public var fileName: String

    public init(path: String, fileName: String) {
        self.path = path
        self.fileName = fileName
    }
}

/// Filename search under a granted workspace root. No content indexing yet.
public enum WorkspaceFileSearch {
    public static func search(
        query: String,
        startingAt path: String?,
        limit: Int = 40
    ) throws -> [WorkspaceSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        guard let root = resolveRoot(path) else {
            throw WorkspaceSearchError.noWorkspaceRoot
        }
        let needle = trimmed.lowercased()
        var hits: [WorkspaceSearchHit] = []
        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        while let item = enumerator?.nextObject() as? URL {
            if hits.count >= limit { break }
            let name = item.lastPathComponent
            guard name.lowercased().contains(needle) else { continue }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue == false
            else { continue }
            hits.append(WorkspaceSearchHit(path: item.path, fileName: name))
        }
        return hits
    }

    private static func resolveRoot(_ path: String?) -> String? {
        guard var current = path, current.isEmpty == false else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: current, isDirectory: &isDirectory),
           isDirectory.boolValue == false
        {
            current = (current as NSString).deletingLastPathComponent
        }
        return current.isEmpty ? nil : current
    }
}

public enum WorkspaceSearchError: Error, Equatable, Sendable {
    case noWorkspaceRoot
}
