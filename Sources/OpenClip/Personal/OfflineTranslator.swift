// OfflineTranslator.swift
// OpenClip
//
// On-device translation through Apple's Translation framework. A session is created per
// call (sessions are not Sendable, so they stay local to a nonisolated task). Chinese script changes (zh-Hans <-> zh-Hant) bypass the framework,
// which does not support them, and go through ChineseConverter instead.
import Foundation
import Translation

enum OfflineTranslatorError: LocalizedError, Equatable {
    case emptyText
    case undetectedLanguage
    case sameLanguage(String)
    case notInstalled(source: String, target: String)
    case unsupported(source: String, target: String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "冇可以翻譯嘅文字"
        case .undetectedLanguage:
            return "認唔到原文語言"
        case .sameLanguage(let code):
            return "原文已經係\(PersonalLanguage.displayName(code))"
        case .notInstalled(let source, let target):
            return "未下載語言包：\(PersonalLanguage.displayName(source)) → \(PersonalLanguage.displayName(target))"
        case .unsupported(let source, let target):
            return "唔支援 \(PersonalLanguage.displayName(source)) → \(PersonalLanguage.displayName(target))"
        case .failed(let message):
            return "翻譯失敗：\(message)"
        }
    }
}

struct TranslationOutcome: Sendable, Equatable {
    let source: String
    let target: String
    let text: String
}

enum LanguagePairStatus: Sendable, Equatable {
    case installed
    case downloadable
    case unsupported
}

/// Speculative translation: the popup asks for translations as soon as it shows, so the result is
/// usually ready by the time the user clicks (on-device inference takes ~0.6 s per request).
/// Requests run one after another, the automatic target first; a new selection drops the old ones.
@MainActor
final class TranslationPrefetcher {
    static let shared = TranslationPrefetcher()
    /// Longer selections are translated on demand only.
    static let maxPrefetchLength = 1_500

    private var text: String?
    private var tasks: [String: Task<TranslationOutcome, Error>] = [:]
    private var tail: Task<Void, Never>?

    /// Starts translating `text` into `target` (nil = automatic) unless already queued.
    func prefetch(_ text: String, target: String?) {
        guard text.count <= Self.maxPrefetchLength else { return }
        _ = task(for: text, target: target, queued: true)
    }

    /// The (possibly already finished) translation. One that was never prefetched starts now,
    /// ahead of any queued speculation.
    func outcome(for text: String, target: String?) async throws -> TranslationOutcome {
        try await task(for: text, target: target, queued: false).value
    }

    private func task(for text: String, target: String?, queued: Bool) -> Task<TranslationOutcome, Error> {
        if self.text != text {
            tasks.values.forEach { $0.cancel() }
            tasks.removeAll()
            tail = nil
            self.text = text
        }
        let key = target ?? "auto"
        if let existing = tasks[key] { return existing }
        let previous = queued ? tail : nil
        let task = Task { @MainActor () throws -> TranslationOutcome in
            await previous?.value
            try Task.checkCancellation()
            return try await OfflineTranslator.shared.translate(text, target: target)
        }
        tasks[key] = task
        if queued { tail = Task { _ = try? await task.value } }
        return task
    }
}

@MainActor
final class OfflineTranslator {
    static let shared = OfflineTranslator()

    /// Translates `text`, detecting the source when `source` is nil and choosing the automatic target
    /// from preferences when `target` is nil.
    func translate(
        _ text: String,
        source: String? = nil,
        target: String? = nil,
        preferences: PersonalLanguagePreferences = PersonalLanguagePreferences()
    ) async throws -> TranslationOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OfflineTranslatorError.emptyText }
        guard let sourceCode = source ?? LanguageDetector.detect(trimmed) else {
            throw OfflineTranslatorError.undetectedLanguage
        }
        let targetCode = target ?? preferences.automaticTarget(for: sourceCode)
        guard sourceCode != targetCode else { throw OfflineTranslatorError.sameLanguage(sourceCode) }

        if sourceCode.hasPrefix("zh") && targetCode.hasPrefix("zh") {
            let script: ChineseScript = targetCode == "zh-Hant" ? .traditional : .simplified
            return TranslationOutcome(source: sourceCode, target: targetCode, text: ChineseConverter.convert(trimmed, to: script))
        }

        switch await status(source: sourceCode, target: targetCode) {
        case .installed: break
        case .downloadable: throw OfflineTranslatorError.notInstalled(source: sourceCode, target: targetCode)
        case .unsupported: throw OfflineTranslatorError.unsupported(source: sourceCode, target: targetCode)
        }

        do {
            let translated = try await Self.translateLines(trimmed, source: sourceCode, target: targetCode)
            return TranslationOutcome(source: sourceCode, target: targetCode, text: Self.tidyPunctuation(translated, target: targetCode))
        } catch {
            throw OfflineTranslatorError.failed(error.localizedDescription)
        }
    }

    func status(source: String, target: String) async -> LanguagePairStatus {
        await Self.pairStatus(source: source, target: target)
    }

    nonisolated static func pairStatus(source: String, target: String) async -> LanguagePairStatus {
        if source.hasPrefix("zh") && target.hasPrefix("zh") { return .installed }
        let raw = await LanguageAvailability().status(
            from: Locale.Language(identifier: source),
            to: Locale.Language(identifier: target)
        )
        switch raw {
        case .installed: return .installed
        case .supported: return .downloadable
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    /// The on-device model pads full-width CJK punctuation with spaces ("平靜 、 快速 。"); drop them.
    nonisolated static func tidyPunctuation(_ text: String, target: String) -> String {
        guard target.hasPrefix("zh") || target == "ja" else { return text }
        return text
            .replacingOccurrences(of: #"[ \t]+([，。、！？；：」』）》〉…])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([，。、！？；：「『（《〈])[ \t]+"#, with: "$1", options: .regularExpression)
    }

    /// Translates line by line so paragraph breaks and blank lines survive.
    nonisolated private static func translateLines(_ text: String, source: String, target: String) async throws -> String {
        let lines = text.components(separatedBy: "\n")
        let requests = lines.enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
        guard !requests.isEmpty else { return text }

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: source),
            target: Locale.Language(identifier: target)
        )
        let responses = try await session.translations(from: requests)
        var output = lines
        for response in responses {
            if let id = response.clientIdentifier, let index = Int(id), output.indices.contains(index) {
                output[index] = response.targetText
            }
        }
        return output.joined(separator: "\n")
    }
}
