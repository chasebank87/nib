/// Snapshot the editor can render. The first surface is TextKit 2; this type is the
/// extension point so Domain/Services do not depend on `NSTextView`.
///
/// TODO(NIB-017): Drive this from a Zig buffer.
public protocol TextSnapshotSourcing: Sendable {
    var text: String { get }
}

extension TextDocumentModel: TextSnapshotSourcing {}
