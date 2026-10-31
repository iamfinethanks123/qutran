// PersonalLanguage.swift
// OpenClip
//
// Language catalog and persisted language preferences for the personal offline translation actions.
// Codes are BCP-47 identifiers accepted by Apple's Translation framework; Chinese is split by script
// (zh-Hant / zh-Hans) because the two are converted locally rather than translated.
import Foundation
import Core

struct PersonalLanguage: Hashable, Identifiable, Sendable {
    let code: String
    /// Name shown in the UI (Traditional Chinese, matching the user's locale).
    let name: String
    /// Short glyph shown on compact buttons.
    let badge: String

    var id: String { code }

    var localeLanguage: Locale.Language { Locale.Language(identifier: code) }

    var isChinese: Bool { code.hasPrefix("zh") }

    /// Every language the on-device Translation framework offers (macOS 26).
    static let all: [PersonalLanguage] = [
        PersonalLanguage(code: "zh-Hant", name: "繁體中文", badge: "繁"),
        PersonalLanguage(code: "zh-Hans", name: "簡體中文", badge: "简"),
        PersonalLanguage(code: "en", name: "英文", badge: "EN"),
        PersonalLanguage(code: "ja", name: "日文", badge: "日"),
        PersonalLanguage(code: "ko", name: "韓文", badge: "한"),
        PersonalLanguage(code: "fr", name: "法文", badge: "FR"),
        PersonalLanguage(code: "de", name: "德文", badge: "DE"),
        PersonalLanguage(code: "es", name: "西班牙文", badge: "ES"),
        PersonalLanguage(code: "it", name: "意大利文", badge: "IT"),
        PersonalLanguage(code: "pt", name: "葡萄牙文", badge: "PT"),
        PersonalLanguage(code: "ru", name: "俄文", badge: "RU"),
        PersonalLanguage(code: "ar", name: "阿拉伯文", badge: "AR"),
        PersonalLanguage(code: "th", name: "泰文", badge: "TH"),
        PersonalLanguage(code: "vi", name: "越南文", badge: "VI"),
        PersonalLanguage(code: "id", name: "印尼文", badge: "ID"),
        PersonalLanguage(code: "hi", name: "印地文", badge: "HI"),
        PersonalLanguage(code: "nl", name: "荷蘭文", badge: "NL"),
        PersonalLanguage(code: "pl", name: "波蘭文", badge: "PL"),
        PersonalLanguage(code: "tr", name: "土耳其文", badge: "TR"),
        PersonalLanguage(code: "uk", name: "烏克蘭文", badge: "UK"),
        PersonalLanguage(code: "sv", name: "瑞典文", badge: "SV"),
        PersonalLanguage(code: "da", name: "丹麥文", badge: "DA"),
        PersonalLanguage(code: "nb", name: "挪威文", badge: "NB"),
    ]

    private static let byCode: [String: PersonalLanguage] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })

    static func named(_ code: String) -> PersonalLanguage? { byCode[code] }

    /// Display name, falling back to the raw code for anything outside the catalog.
    static func displayName(_ code: String) -> String { byCode[code]?.name ?? code }
}

extension SettingKey where Value == String {
    /// Language most selections are translated into.
    static var personalPrimaryLanguage: SettingKey<String> { SettingKey<String>("personal.translate.primary", defaultValue: "zh-Hant") }
    /// Target used when the selection is already in the primary language.
    static var personalSecondaryLanguage: SettingKey<String> { SettingKey<String>("personal.translate.secondary", defaultValue: "en") }
    /// Locked target for 翻譯 and 譯後替換; empty means automatic (primary / secondary).
    static var personalLockedLanguage: SettingKey<String> { SettingKey<String>("personal.translate.locked", defaultValue: "") }
}

extension SettingKey where Value == Bool {
    static var personalDidSeedActionOrder: SettingKey<Bool> { SettingKey<Bool>("personal.didSeedActionOrder", defaultValue: false) }
    static var personalDidSeedAIPresets: SettingKey<Bool> { SettingKey<Bool>("personal.didSeedAIPresets", defaultValue: false) }
    static var personalDidSeedPopupAppearance: SettingKey<Bool> { SettingKey<Bool>("personal.didSeedPopupAppearance", defaultValue: false) }
}

extension SettingKey where Value == [String] {
    /// Ordered languages offered in the "Translate to…" menu.
    static var personalFavoriteLanguages: SettingKey<[String]> {
        SettingKey<[String]>("personal.translate.favorites", defaultValue: ["zh-Hant", "en", "ja", "zh-Hans"])
    }
}

/// Reads the language preferences, sanitising anything the catalog does not know.
struct PersonalLanguagePreferences: Sendable {
    let primary: String
    let secondary: String
    let favorites: [String]
    /// When set, 翻譯 and 譯後替換 always translate into this language.
    let locked: String?

    init(primary: String, secondary: String, favorites: [String], locked: String? = nil) {
        let known = { (code: String) in PersonalLanguage.named(code) != nil }
        self.primary = known(primary) ? primary : "zh-Hant"
        let secondaryCode = known(secondary) ? secondary : "en"
        self.secondary = secondaryCode == self.primary ? (self.primary == "en" ? "zh-Hant" : "en") : secondaryCode
        var seen = Set<String>()
        let cleaned = favorites.filter { known($0) && seen.insert($0).inserted }
        self.favorites = cleaned.isEmpty ? [self.primary, self.secondary] : cleaned
        self.locked = locked.flatMap { known($0) ? $0 : nil }
    }

    init(settingsStore: any SettingsStore = DefaultSettingsStore.shared) {
        self.init(
            primary: settingsStore.get(.personalPrimaryLanguage),
            secondary: settingsStore.get(.personalSecondaryLanguage),
            favorites: settingsStore.get(.personalFavoriteLanguages),
            locked: settingsStore.get(.personalLockedLanguage)
        )
    }

    /// Target for 翻譯 / 譯後替換: the locked language, else the primary language unless the text is
    /// already in it. Text already in the locked language falls back to the automatic pair.
    func automaticTarget(for source: String) -> String {
        if let locked, locked != source { return locked }
        return source == primary ? secondary : primary
    }

    /// Short description of where 翻譯 goes, for button titles ("英文", or "自動").
    var targetSummary: String {
        locked.map(PersonalLanguage.displayName) ?? "自動"
    }
}
