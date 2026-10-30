// BrandColor.swift
// OpenClip
//
// OpenClip's own blue, taken from the marketing site rather than the app icon: getopenclip.app
// uses `#0071e3` and the icon uses `#0084FF`, close but not the same, and the site is what the
// rest of the brand follows (see `docs/dmg.md`).

import SwiftUI
import AppKit

public extension Color {
    /// The brand blue. In the settings sidebar it is reserved for rows OpenClip ships, so a
    /// third-party extension's generated tint can never claim it — see `SettingsTint`.
    static let openClipBrand = Color(red: 0x9A / 255, green: 0x76 / 255, blue: 0x44 / 255)
    /// Qutran's single accent: warm bronze, used in place of the system accent across the UI.
    static let qutranAccent = Color(nsColor: .qutranAccent)
}

public extension NSColor {
    static let qutranAccent = NSColor(srgbRed: 0x9A / 255, green: 0x76 / 255, blue: 0x44 / 255, alpha: 1)
    /// Warm cream canvas shared by every Qutran window and the light popup surface.
    static let qutranCream = NSColor(srgbRed: 0.973, green: 0.957, blue: 0.925, alpha: 1)
}
