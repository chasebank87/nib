import Combine
import Foundation

@MainActor
public protocol EditorDocumenting: ObservableObject {
    var text: String { get set }
    var isDocumentEdited: Bool { get }
    var isPalettePresented: Bool { get set }
    func performOpen()
    func performSave()
    func performSaveAs()
}

public extension Notification.Name {
    static let nibToggleCommandPalette = Notification.Name("nib.toggleCommandPalette")
    static let nibAppearanceDidChange = Notification.Name("nib.appearanceDidChange")
}
