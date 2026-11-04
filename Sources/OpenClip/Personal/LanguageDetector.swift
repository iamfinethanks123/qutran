// LanguageDetector.swift
// OpenClip
//
// Offline language identification for selections, mapped onto the PersonalLanguage catalog.
// NaturalLanguage picks the language; Chinese script is decided by ChineseConverter, which is
// more reliable than the recognizer's simplified/traditional split on short text.
import Foundation
import NaturalLanguage
import os

struct TextAnalysisCache<Value: Sendable>: Sendable {
    private struct Snapshot: Sendable {
        let text: String
        let value: Value
    }
    private let snapshot = OSAllocatedUnfairLock<Snapshot?>(initialState: nil)

    func value(for text: String, compute: () -> Value) -> Value {
        if let cached = snapshot.withLock({ $0 }), cached.text == text { return cached.value }
        let value = compute()
        snapshot.withLock { $0 = Snapshot(text: text, value: value) }
        return value
    }
}

enum LanguageDetector {
    private static let cache = TextAnalysisCache<String?>()
    /// Catalog code of the dominant language, or nil when undetermined or unsupported.
    static func detect(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return cache.value(for: trimmed) { recognize(trimmed) }
    }

    private static func recognize(_ trimmed: String) -> String? {
        // Kana means Japanese even when kanji dominate.
        if trimmed.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) {
            return "ja"
        }
        if ChineseConverter.hanRatio(trimmed) > 0.5 {
            return ChineseConverter.detectScript(trimmed) == .simplified ? "zh-Hans" : "zh-Hant"
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = PersonalLanguage.all.compactMap { naturalLanguage(for: $0.code) }
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else { return nil }
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return ChineseConverter.detectScript(trimmed) == .simplified ? "zh-Hans" : "zh-Hant"
        case .norwegian:
            return "nb"
        default:
            let code = language.rawValue
            return PersonalLanguage.named(code) == nil ? nil : code
        }
    }

    private static func naturalLanguage(for code: String) -> NLLanguage? {
        switch code {
        case "zh-Hant": return .traditionalChinese
        case "zh-Hans": return .simplifiedChinese
        case "nb": return .norwegian
        default: return NLLanguage(rawValue: code)
        }
    }
}
