import AppKit
import NibDomain
import SwiftUI

public enum HexColor {
    public static func nsColor(from hex: String) -> NSColor {
        let parsed = parse(hex)
        return NSColor(
            srgbRed: parsed.red,
            green: parsed.green,
            blue: parsed.blue,
            alpha: parsed.alpha
        )
    }

    public static func color(from hex: String) -> Color {
        Color(nsColor: nsColor(from: hex))
    }

    public static func parse(_ hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6 || value.count == 8, let int = UInt32(value, radix: 16) else {
            return (0.5, 0.5, 0.5, 1)
        }
        if value.count == 6 {
            return (
                CGFloat((int >> 16) & 0xFF) / 255,
                CGFloat((int >> 8) & 0xFF) / 255,
                CGFloat(int & 0xFF) / 255,
                1
            )
        }
        return (
            CGFloat((int >> 24) & 0xFF) / 255,
            CGFloat((int >> 16) & 0xFF) / 255,
            CGFloat((int >> 8) & 0xFF) / 255,
            CGFloat(int & 0xFF) / 255
        )
    }
}

extension Theme {
    public func color(_ token: ThemeToken) -> Color {
        HexColor.color(from: hex(for: token))
    }

    public func nsColor(_ token: ThemeToken) -> NSColor {
        HexColor.nsColor(from: hex(for: token))
    }
}
