import Foundation
import NibDomain

/// Runs an approved shell command after `ToolPermission.runCommand` is granted.
/// Never invoked silently by the agent — the UI must confirm the exact command.
public enum ApprovedCommandRunner {
    public static func run(
        _ command: String,
        workingDirectory: String?,
        timeoutSeconds: TimeInterval = 30
    ) throws -> ApprovedCommandResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw ApprovedCommandError.emptyCommand
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", trimmed]
        if let workingDirectory, workingDirectory.isEmpty == false {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw ApprovedCommandError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return ApprovedCommandResult(
            command: trimmed,
            exitCode: Int(process.terminationStatus),
            stdout: out,
            stderr: err
        )
    }
}

public struct ApprovedCommandResult: Equatable, Sendable {
    public var command: String
    public var exitCode: Int
    public var stdout: String
    public var stderr: String

    public init(command: String, exitCode: Int, stdout: String, stderr: String) {
        self.command = command
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var summary: String {
        var parts = ["$ \(command)", "exit \(exitCode)"]
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty == false {
            parts.append(out)
        }
        if err.isEmpty == false {
            parts.append("stderr:\n\(err)")
        }
        return parts.joined(separator: "\n")
    }
}

public enum ApprovedCommandError: Error, Equatable, Sendable {
    case emptyCommand
    case timedOut
}
