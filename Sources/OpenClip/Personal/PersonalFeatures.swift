// PersonalFeatures.swift
// OpenClip
//
// Composition point for the personal (offline-first) actions. AppDelegate calls `registerActions()`
// once after the core builtins load; the "Translate to…" children follow the favourite languages.
import AppKit
import Combine
import Core

@MainActor
enum PersonalFeatures {
    private static var favoritesObserver: AnyCancellable?
    private static var registeredTargetIDs: [String] = []

    /// Bar order seeded once for a fresh install: the everyday actions first. Each action still only
    /// shows when it fits the selection, so the bar stays short. Users can reorder in Settings › Customize.
    static let defaultActionOrder = [
        "builtin.copy", TranslateAction.automaticID, TranslateAction.groupID, DefineAction.actionID,
        "builtin.calculate", ChineseConvertAction.groupID, "builtin.calendar", "builtin.openurl",
        "personal.maps", "personal.call", "builtin.search", "personal.search.sites", "personal.speak",
        "personal.texttools.text", "personal.texttools.encode", "builtin.cut", "builtin.paste", "builtin.aiTools",
    ]

    static func seedActionOrderIfNeeded(settingsStore: any SettingsStore) {
        guard !settingsStore.get(.personalDidSeedActionOrder) else { return }
        settingsStore.set(.personalDidSeedActionOrder, value: true)
        guard settingsStore.get(.actionOrder).isEmpty else { return }
        settingsStore.set(.actionOrder, value: defaultActionOrder)
    }

    /// Extra on-device AI prompts added once alongside OpenClip's own (Proofread, Rewrite, Formal Tone…).
    /// Short tasks only: the Apple Intelligence model has a small context window.
    static let extraAIPresets = [
        AIActionPreset(id: "personal_casual", title: "輕鬆語氣",
                       prompt: "Rewrite in a friendly, casual tone. Preserve the meaning, facts and original language. Return only the rewritten text."),
        AIActionPreset(id: "personal_reply", title: "擬回覆",
                       prompt: "Draft a short, polite reply to this message, written in the same language as the message. Return only the reply."),
        AIActionPreset(id: "personal_cantonese", title: "港式口語",
                       prompt: "Rewrite the text as natural Hong Kong Cantonese written colloquially in Traditional Chinese characters. Preserve the meaning. Return only the rewritten text."),
    ]

    static func seedAIPresetsIfNeeded(settingsStore: any SettingsStore, manager: AIServiceManager = .shared) {
        guard !settingsStore.get(.personalDidSeedAIPresets) else { return }
        settingsStore.set(.personalDidSeedAIPresets, value: true)
        let existing = Set(manager.presets.map(\.id))
        let missing = extraAIPresets.filter { !existing.contains($0.id) }
        guard !missing.isEmpty else { return }
        manager.presets = manager.presets + missing
    }

    /// The popup bar starts in the light (cream) classic theme to match the hub. Changeable in Settings › Appearance.
    static func seedPopupAppearanceIfNeeded(settingsStore: any SettingsStore) {
        guard !settingsStore.get(.personalDidSeedPopupAppearance) else { return }
        settingsStore.set(.personalDidSeedPopupAppearance, value: true)
        settingsStore.set(.popupTheme, value: "classic")
        settingsStore.set(.popupThemeColor, value: "light")
    }

    static func registerActions(settingsStore: any SettingsStore = DefaultSettingsStore.shared) {
        // The test host is this app: keep its first-run seeding out of the shared settings domain.
        if NSClassFromString("XCTestCase") == nil {
            seedActionOrderIfNeeded(settingsStore: settingsStore)
            seedAIPresetsIfNeeded(settingsStore: settingsStore)
            seedPopupAppearanceIfNeeded(settingsStore: settingsStore)
        }
        let coordinator = ActionCoordinator.shared
        coordinator.register(action: TranslateAction())
        coordinator.register(action: TranslateAction.group())
        registerFavoriteTargets(settingsStore: settingsStore)

        coordinator.register(action: ChineseConvertAction.group())
        coordinator.register(action: ChineseConvertAction(script: .traditional))
        coordinator.register(action: ChineseConvertAction(script: .simplified))

        for action in PersonalUtilityActions.all() {
            coordinator.register(action: action)
        }

        favoritesObserver = settingsStore.publisher(for: .personalFavoriteLanguages)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                MainActor.assumeIsolated { registerFavoriteTargets(settingsStore: settingsStore) }
            }
    }

    /// `OPENCLIP_PERSONAL_HUB=<translate|history|languages>` opens the hub at launch (handy for screenshots).
    /// An environment variable, because the app's CLI parser rejects unknown arguments.
    static func handleLaunchEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let value = environment["OPENCLIP_PERSONAL_HUB"] else { return }
        PersonalHubWindowController.show(PersonalHubSection(rawValue: value) ?? .translate)
    }

    /// `OPENCLIP_PERSONAL_DEMO_TEXT=<text>` shows the real popup bar for that text at the screen centre,
    /// so the bar can be exercised without a live selection (and without Accessibility access).
    static func showDemoPopup(using popup: PopupWindowController?, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let popup, let text = environment["OPENCLIP_PERSONAL_DEMO_TEXT"], !text.isEmpty else { return }
        let frame = NSScreen.main?.visibleFrame ?? .zero
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let context = SelectionContext(
            text: text,
            sourceApp: AppIdentity(bundleIdentifier: "com.apple.Notes", localizedName: "Notes"),
            cursorPosition: point,
            mouseDownLocation: point
        )
        // After launch-time windows (onboarding) settle, or their activation dismisses the bar at once.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            popup.show(for: context, pasteAvailable: false)
        }
    }

    /// `QUTRAN_SNAPSHOT_DIR=<dir>` opens Settings and the hub, then writes a PNG of every visible window
    /// into `dir` (rendered in-process, so no Screen Recording permission is needed). Design QA aid.
    static func writeWindowSnapshots(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let path = environment["QUTRAN_SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        let settingsPage = environment["QUTRAN_SNAPSHOT_SETTINGS"].flatMap(PreferenceTab.init(rawValue:))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            SettingsWindowController.show(tab: settingsPage)
            try? await Task.sleep(for: .seconds(2))
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (index, window) in NSApp.windows.enumerated() where window.isVisible {
                guard let view = window.contentView?.superview ?? window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                let name = window.title.isEmpty ? "window-\(index)" : window.title
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: directory.appendingPathComponent("\(name).png"))
            }
            Log.personal.info("Wrote window snapshots")
        }
    }

    /// Installs (and trusts) the extension packages bundled under `PersonalExtensions/` when they are
    /// missing or their bundled `version` changed. A user-edited copy with the same version is kept.
    static func installBundledExtensions(into directory: URL = Constants.extensionsDirectory) async {
        guard let bundled = Bundle.main.url(forResource: "PersonalExtensions", withExtension: nil),
              let packages = try? FileManager.default.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil) else {
            Log.personal.error("Bundled personal extensions not found")
            return
        }
        let manager = ExtensionManager.shared
        let trust = DefaultSettingsStore.shared.get(.extensionTrust)
        for package in packages where package.pathExtension == "openclipext" {
            guard let manifest = manifestInfo(at: package) else { continue }
            let installedURL = directory.appendingPathComponent(package.lastPathComponent)
            let installed = manifestInfo(at: installedURL)
            do {
                if installed?.version != manifest.version {
                    _ = try await manager.installExtension(from: package, targetDir: directory, source: "local")
                    await manager.enablePackage(packageID: manifest.identifier, in: directory)
                    Log.personal.info("Installed bundled extension \(manifest.identifier, privacy: .public) \(manifest.version, privacy: .public)")
                } else if trust[manifest.identifier] == nil {
                    await manager.enablePackage(packageID: manifest.identifier, in: directory)
                }
            } catch {
                Log.personal.error("Installing \(manifest.identifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func manifestInfo(at package: URL) -> (identifier: String, version: String)? {
        guard let data = try? Data(contentsOf: package.appendingPathComponent("openclip.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let identifier = json["identifier"] as? String else { return nil }
        return (identifier, json["version"] as? String ?? "0")
    }

    private static func registerFavoriteTargets(settingsStore: any SettingsStore) {
        let preferences = PersonalLanguagePreferences(settingsStore: settingsStore)
        let actions = preferences.favorites.compactMap(PersonalLanguage.named).map(TranslateAction.init(target:))
        // Unregister everything first so the sub-menu follows the favourites' order.
        for staleID in registeredTargetIDs {
            ActionCoordinator.shared.unregister(actionID: staleID)
        }
        for action in actions {
            ActionCoordinator.shared.register(action: action)
        }
        registeredTargetIDs = actions.map(\.id)
    }
}
