// ChineseConverter.swift
// OpenClip
//
// Offline Simplified <-> Traditional Chinese conversion using the system ICU transforms.
// Character-level only: no regional vocabulary substitution (by design).
import Foundation

enum ChineseScript: Sendable, Equatable {
    case traditional
    case simplified
}

enum ChineseConverter {
    private static let toTraditionalTransform = StringTransform("Hans-Hant")
    private static let toSimplifiedTransform = StringTransform("Hant-Hans")

    static func toTraditional(_ text: String) -> String {
        text.applyingTransform(toTraditionalTransform, reverse: false) ?? text
    }

    static func toSimplified(_ text: String) -> String {
        text.applyingTransform(toSimplifiedTransform, reverse: false) ?? text
    }

    static func convert(_ text: String, to script: ChineseScript) -> String {
        script == .traditional ? toTraditional(text) : toSimplified(text)
    }

    /// True when the text contains at least one CJK unified ideograph.
    static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { isHan($0) }
    }

    /// Ratio of Han ideographs among letters (ignores punctuation, digits and whitespace).
    static func hanRatio(_ text: String) -> Double {
        var han = 0
        var letters = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            letters += 1
            if isHan(scalar) { han += 1 }
        }
        return letters == 0 ? 0 : Double(han) / Double(letters)
    }

    /// Guesses the script by counting characters each direction would change. Returns nil when the
    /// text has no Han characters or only script-neutral ones.
    static func detectScript(_ text: String) -> ChineseScript? {
        guard containsHan(text) else { return nil }
        let simplifiedOnly = changedCharacterCount(text, toTraditional(text))
        let traditionalOnly = changedCharacterCount(text, toSimplified(text))
        if simplifiedOnly == 0 && traditionalOnly == 0 { return nil }
        return traditionalOnly >= simplifiedOnly ? .traditional : .simplified
    }

    private static func changedCharacterCount(_ lhs: String, _ rhs: String) -> Int {
        zip(lhs, rhs).reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0xF900...0xFAFF: return true
        default: return false
        }
    }
}
