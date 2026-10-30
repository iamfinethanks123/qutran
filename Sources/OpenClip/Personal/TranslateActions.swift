// TranslateActions.swift
// OpenClip
//
// Popup actions for offline translation:
// - `personal.translate`: detects the language and translates into the automatic target.
// - `personal.translateTo` group: one sub-action per favourite language.
// - `personal.chinese` group: Simplified <-> Traditional conversion.
import Foundation
import Core

/// A group row whose visibility is decided by a predicate instead of extension rules.
struct PersonalGroupAction: ConfigurableAction, SubActionProviding {
    let id: String
    let title: String
    let icon: ActionIcon
    let keywords: [String]
    let isVisible: @Sendable (String) -> Bool

    var chrome: ActionChrome { ActionChrome(popupBehavior: .showSubActions) }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        isVisible(context.selection.text)
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult { .none }

    @MainActor
    func subActions(in catalog: [any Action]) -> [any Action] {
        catalog.filter { $0.id != id && $0.id.hasPrefix(id + ".") }
    }
}

enum PersonalTextRules {
    static let maxTranslateLength = 8_000

    /// Selections worth translating: some letters, not just numbers, symbols or a URL.
    static func isTranslatable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxTranslateLength else { return false }
        guard trimmed.unicodeScalars.contains(where: { $0.properties.isAlphabetic }) else { return false }
        if !trimmed.contains(" "), let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true { return false }
        return true
    }
}

struct TranslateAction: ConfigurableAction {
    static let automaticID = "personal.translate"
    static let groupID = "personal.translateTo"

    let id: String
    let title: String
    let icon: ActionIcon
    /// nil translates into the automatic target (primary, or secondary when already primary).
    let fixedTarget: String?

    init() {
        id = Self.automaticID
        title = "翻譯"
        icon = .symbol("translate")
        fixedTarget = nil
    }

    init(target: PersonalLanguage) {
        id = "\(Self.groupID).\(target.code)"
        title = target.name
        icon = .text(target.badge)
        fixedTarget = target.code
    }

    var keywords: [String] { ["translate", "translation", "翻譯", "fanyi"] + (fixedTarget.map { [$0] } ?? []) }

    var chrome: ActionChrome {
        ActionChrome(outputKind: .text, recommendedResult: .preview)
    }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        let text = context.selection.text
        guard PersonalTextRules.isTranslatable(text) else { return false }
        // "Translate to X" is pointless when the text is already X.
        if let fixedTarget, LanguageDetector.detect(text) == fixedTarget { return false }
        // Visible means likely to be clicked: start translating now so the click feels instant.
        // Favourite targets are speculated only for short text, behind the automatic one.
        if fixedTarget == nil || text.count <= Self.maxFavoritePrefetchLength {
            TranslationPrefetcher.shared.prefetch(text, target: fixedTarget)
        }
        return true
    }

    static let maxFavoritePrefetchLength = 300

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        do {
            return .text(try await Self.translateAndRecord(context, target: fixedTarget).text)
        } catch let error as OfflineTranslatorError {
            return .toast(Self.feedback(for: error))
        }
    }

    /// Translates the selection (reusing any prefetched result) and logs it in the vocabulary book.
    @MainActor
    static func translateAndRecord(_ context: ActionContext, target: String?) async throws -> TranslationOutcome {
        let outcome = try await TranslationPrefetcher.shared.outcome(for: context.selection.text, target: target)
        PersonalHistoryStore.shared.record(
            kind: .translation,
            original: context.selection.text,
            result: outcome.text,
            source: outcome.source,
            target: outcome.target,
            app: context.selection.sourceApp.localizedName
        )
        return outcome
    }

    static func feedback(for error: OfflineTranslatorError) -> StatusFeedback {
        switch error {
        case .notInstalled:
            return StatusFeedback(message: (error.errorDescription ?? "") + "（選單列 › 語言包）", style: .error, symbolName: "arrow.down.circle")
        case .sameLanguage, .undetectedLanguage, .emptyText:
            return StatusFeedback(message: error.errorDescription ?? "", style: .info, symbolName: "character.bubble")
        case .unsupported, .failed:
            return StatusFeedback(message: error.errorDescription ?? "", style: .error, symbolName: "exclamationmark.triangle")
        }
    }

    static func group() -> PersonalGroupAction {
        PersonalGroupAction(
            id: groupID,
            title: "翻譯為…",
            icon: .symbol("globe"),
            keywords: ["translate to", "翻譯為"],
            isVisible: { text in PersonalTextRules.isTranslatable(text) }
        )
    }
}

/// Translates into the automatic target and pastes over the selection. Shown only where the
/// selection can be replaced (editable field, Paste available).
struct TranslateReplaceAction: ConfigurableAction, PasteRequiringAction {
    let id = "personal.translateReplace"
    var title: String { "譯後替換" }
    let icon = ActionIcon.symbol("character.cursor.ibeam")
    var keywords: [String] { ["translate replace", "replace", "替換", "翻譯替換"] }

    var chrome: ActionChrome {
        ActionChrome(requiresLiveSelection: true, showsLoading: true, loadingMessage: "翻譯中…",
                     outputKind: .text, recommendedResult: .paste)
    }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        let text = context.selection.text
        guard context.selection.isEditable != false, PersonalTextRules.isTranslatable(text) else { return false }
        TranslationPrefetcher.shared.prefetch(text, target: nil)
        return true
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        do {
            return .paste(try await TranslateAction.translateAndRecord(context, target: nil).text)
        } catch let error as OfflineTranslatorError {
            return .toast(TranslateAction.feedback(for: error))
        }
    }
}

struct ChineseConvertAction: ConfigurableAction {
    static let groupID = "personal.chinese"

    let script: ChineseScript

    var id: String { "\(Self.groupID).\(script == .traditional ? "toTraditional" : "toSimplified")" }
    var title: String { script == .traditional ? "轉繁體" : "轉簡體" }
    var icon: ActionIcon { .text(script == .traditional ? "繁" : "简") }
    var keywords: [String] { ["chinese", "traditional", "simplified", "繁簡", "简繁"] }

    var chrome: ActionChrome {
        ActionChrome(isInlineResult: true, outputKind: .text, recommendedResult: .pasteOrCopy)
    }

    func convert(_ text: String) -> String? {
        let converted = ChineseConverter.convert(text, to: script)
        return converted == text ? nil : converted
    }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        let text = context.selection.text
        return text.count <= PersonalTextRules.maxTranslateLength && convert(text) != nil
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        guard let converted = convert(context.selection.text) else { return .none }
        return .text(converted)
    }

    static func group() -> PersonalGroupAction {
        PersonalGroupAction(
            id: groupID,
            title: "繁簡",
            icon: .text("繁简"),
            keywords: ["繁簡", "简繁", "chinese"],
            isVisible: { text in
                text.count <= PersonalTextRules.maxTranslateLength && ChineseConverter.containsHan(text)
                    && (ChineseConverter.toTraditional(text) != text || ChineseConverter.toSimplified(text) != text)
            }
        )
    }
}
