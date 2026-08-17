import Foundation
import NibDomain

public final class FileRecoveryStore: DocumentRecoveryStoring, @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = support
                .appendingPathComponent("com.chaseelder.nib", isDirectory: true)
                .appendingPathComponent("Recovery", isDirectory: true)
        }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func save(_ payload: DocumentRecoveryPayload) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL(for: payload.id), options: .atomic)
    }

    public func loadAll() throws -> [DocumentRecoveryPayload] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try urls.filter { $0.pathExtension == "json" }.map { url in
            let data = try Data(contentsOf: url)
            return try decoder.decode(DocumentRecoveryPayload.self, from: data)
        }.sorted { $0.updatedAt < $1.updatedAt }
    }

    public func remove(id: UUID) throws {
        let url = fileURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func removeAll() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
