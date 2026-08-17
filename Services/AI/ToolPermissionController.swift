import Combine
import Foundation
import NibDomain

/// Applies text replacements after `ToolPermission.applyEdits` is granted (NIB-015).
public enum TextPatchApplier {
    public static func replaceUTF16Range(
        in text: String,
        range: Range<Int>,
        with replacement: String
    ) throws -> String {
        let ns = text as NSString
        let length = ns.length
        let location = range.lowerBound
        let end = range.upperBound
        guard location >= 0, end >= location, end <= length else {
            throw TextPatchError.outOfBounds
        }
        return ns.substring(to: location) + replacement + ns.substring(from: end)
    }
}

public enum TextPatchError: Error, Equatable, Sendable {
    case outOfBounds
    case emptyPatch
}

/// Session grants for agent/AI tools. Destructive actions require an explicit grant.
@MainActor
public final class ToolPermissionController: ObservableObject {
    @Published public private(set) var grants: ToolPermission

    public init(grants: ToolPermission = [.readCurrentFile, .sendToProvider]) {
        self.grants = grants
    }

    public func has(_ permission: ToolPermission) -> Bool {
        grants.contains(permission)
    }

    public func grant(_ permission: ToolPermission) {
        grants.formUnion(permission)
    }

    public func revoke(_ permission: ToolPermission) {
        grants.subtract(permission)
    }

    /// Returns true when already granted, or when the caller records an explicit grant.
    public func require(_ permission: ToolPermission, allowPromptGrant: Bool) throws {
        if has(permission) { return }
        if allowPromptGrant {
            grant(permission)
            return
        }
        throw AIProviderError.permissionDenied(permission)
    }
}
