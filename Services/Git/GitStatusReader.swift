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
