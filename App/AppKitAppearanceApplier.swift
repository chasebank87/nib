import AppKit
import NibDomain
import NibServices

final class AppKitAppearanceApplier: AppearanceApplying {
    func apply(_ preference: AppearancePreference) {
        switch preference {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
