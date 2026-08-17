import AppKit

/// Caps the Open Recent menu. `NSDocumentController.maximumRecentDocumentCount`
/// is read-only in current SDKs, so the shared controller must be this subclass.
@objc(NibDocumentController)
final class NibDocumentController: NSDocumentController {
    override var maximumRecentDocumentCount: Int { 12 }
}
