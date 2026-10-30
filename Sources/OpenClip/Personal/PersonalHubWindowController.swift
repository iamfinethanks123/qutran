// PersonalHubWindowController.swift
// OpenClip
//
// Hosts the personal hub (quick translate, vocabulary book, languages) in a native macOS 26 window,
// plus the menu bar items and global hotkey that open it.
import AppKit
import SwiftUI
import KeyboardShortcuts
import Core

enum PersonalHubSection: String, CaseIterable, Identifiable, Hashable {
    case translate
    case history
    case languages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translate: return "翻譯"
        case .history: return "生字簿"
        case .languages: return "語言"
        }
    }

    var symbol: String {
        switch self {
        case .translate: return "translate"
        case .history: return "book.closed"
        case .languages: return "globe"
        }
    }
}

extension KeyboardShortcuts.Name {
    static let personalQuickTranslate = Self("personalQuickTranslate", initial: .init(.t, modifiers: [.command, .option]))
}

@MainActor
final class PersonalHubModel: ObservableObject {
    @Published var section: PersonalHubSection = .translate
    /// Bumped to ask the translate pane to focus its input.
    @Published var focusRequest = 0
    @Published var pendingInput: String?
}

@MainActor
final class PersonalHubWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PersonalHubWindowController()

    let model = PersonalHubModel()

    static func show(_ section: PersonalHubSection, input: String? = nil) {
        shared.present(section, input: input)
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenClip"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        // Always the light cream look, whatever the system appearance.
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = HubTheme.nsCanvas
        window.minSize = NSSize(width: 740, height: 520)
        window.setFrameAutosaveName("PersonalHubWindow.v2")
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        let hosting = NSHostingController(rootView: PersonalHubView(model: model))
        hosting.sizingOptions = [.minSize]
        window.contentViewController = hosting
        if !window.setFrameUsingName("PersonalHubWindow.v2") {
            window.setContentSize(NSSize(width: 900, height: 600))
            window.center()
        }
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(_ section: PersonalHubSection, input: String?) {
        guard let window else { return }
        model.section = section
        if let input { model.pendingInput = input }
        if section == .translate { model.focusRequest += 1 }
        if !window.isVisible { AppActivationPolicy.enter() }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        AppActivationPolicy.leave()
    }
}

/// Menu bar entries and the global quick-translate hotkey.
@MainActor
final class PersonalMenu: NSObject {
    static let shared = PersonalMenu()

    private var hotkeyInstalled = false

    func installHotkey() {
        guard !hotkeyInstalled else { return }
        hotkeyInstalled = true
        KeyboardShortcuts.onKeyUp(for: .personalQuickTranslate) {
            Task { @MainActor in PersonalHubWindowController.show(.translate) }
        }
    }

    func addItems(to menu: NSMenu) {
        let translate = item("快速翻譯…", symbol: "translate", action: #selector(openTranslate))
        translate.setShortcut(for: .personalQuickTranslate)
        menu.addItem(translate)
        menu.addItem(item("生字簿", symbol: "book.closed", action: #selector(openHistory)))
        menu.addItem(item("語言與語言包…", symbol: "globe", action: #selector(openLanguages)))
    }

    private func item(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    @objc private func openTranslate() { PersonalHubWindowController.show(.translate) }
    @objc private func openHistory() { PersonalHubWindowController.show(.history) }
    @objc private func openLanguages() { PersonalHubWindowController.show(.languages) }
}
