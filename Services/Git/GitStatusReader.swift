import Foundation
import NibDomain

public struct GitStatusSnapshot: Equatable, Sendable {
    public var branch: String?
    public var porcelain: String
    public var diffStat: String

    public init(branch: String? = nil, porcelain: String = "", diffStat: String = "") {
        self.branch = branch
        self.porcelain = porcelain
        self.diffStat = diffStat
    }

    public var summary: String {
        var lines: [String] = []
        if let branch, branch.isEmpty == false {
            lines.append("branch: \(branch)")
        }
        if porcelain.isEmpty == false {
            lines.append(porcelain)
        }
        if diffStat.isEmpty == false {
            lines.append(diffStat)
        }
        return lines.joined(separator: "\n")
    }

    public var isEmpty: Bool {
        porcelain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && diffStat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum GitFileMark: String, Equatable, Sendable {
    case clean
    case modified
    case staged
    case untracked
    case unknown

    public var statusLabel: String {
        switch self {
        case .clean: return ""
        case .modified: return "M"
        case .staged: return "S"
        case .untracked: return "U"
        case .unknown: return ""
        }
    }
}

/// Read-only Git inspection. Never mutates the repository.
public enum GitStatusReader {
    public static func snapshot(startingAt path: String?) throws -> GitStatusSnapshot {
        guard let root = findGitRoot(startingAt: path) else {
            return GitStatusSnapshot(porcelain: "(not a git repository)")
        }
        let branch = try? runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let porcelain = try runGit(["status", "--porcelain"], in: root)
        let diffStat = (try? runGit(["diff", "--stat"], in: root)) ?? ""
        return GitStatusSnapshot(branch: branch, porcelain: porcelain, diffStat: diffStat)
    }

    public static func fileMark(for path: String?) -> GitFileMark {
        guard let path, path.isEmpty == false else { return .unknown }
        guard let root = findGitRoot(startingAt: path) else { return .unknown }
        let relative = relativePath(path, from: root)
        guard let porcelain = try? runGit(["status", "--porcelain", "--", relative], in: root) else {
            return .unknown
        }
        return mark(for: path, porcelain: porcelain)
    }

    public static func mark(for path: String, porcelain: String) -> GitFileMark {
        let name = (path as NSString).lastPathComponent
        let lines = porcelain.split(separator: "\n").map(String.init)
        guard let line = lines.first(where: { porcelainLine($0, matches: path, name: name) }) else {
            return .clean
        }
        guard line.count >= 2 else { return .clean }
        let index = line[line.startIndex]
        let worktree = line[line.index(after: line.startIndex)]
        if index == "?" { return .untracked }
        if worktree == "M" || worktree == "D" { return .modified }
        if index == "M" || index == "A" || index == "D" { return .staged }
        return .clean
    }

    private static func porcelainLine(_ line: String, matches path: String, name: String) -> Bool {
        guard line.count >= 3 else { return false }
        var payload = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        if payload.hasPrefix("\"") {
            payload = payload.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        if let arrow = payload.range(of: " -> ") {
            payload = String(payload[arrow.upperBound...])
        }
        if payload == name || payload.hasSuffix("/" + name) {
            return true
        }
        return path.hasSuffix("/" + payload)
    }

    private static func relativePath(_ path: String, from root: String) -> String {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return (path as NSString).lastPathComponent
    }

    public static func findGitRoot(startingAt path: String?) -> String? {
        guard var current = path, current.isEmpty == false else { return nil }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: current, isDirectory: &isDirectory),
           isDirectory.boolValue == false
        {
            current = (current as NSString).deletingLastPathComponent
        }
        var directory = current
        while directory.isEmpty == false, directory != "/" {
            let gitDir = (directory as NSString).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir) {
                return directory
            }
            directory = (directory as NSString).deletingLastPathComponent
        }
        return nil
    }

    private static func runGit(_ arguments: [String], in directory: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitStatusError.commandFailed(err.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public enum GitStatusError: Error, Equatable, Sendable {
    case commandFailed(String)
}
