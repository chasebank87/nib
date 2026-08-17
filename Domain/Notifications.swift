import Foundation

public extension Notification.Name {
    static let nibToggleCommandPalette = Notification.Name("nib.toggleCommandPalette")
    static let nibAppearanceDidChange = Notification.Name("nib.appearanceDidChange")
    static let nibEditorSettingsDidChange = Notification.Name("nib.editorSettingsDidChange")
    static let nibGoToLine = Notification.Name("nib.goToLine")
    static let nibFind = Notification.Name("nib.find")
    static let nibComplete = Notification.Name("nib.complete")
    static let nibHover = Notification.Name("nib.hover")
}
