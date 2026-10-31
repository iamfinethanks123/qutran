import XCTest
import AppKit
@testable import OpenClip
@testable import Core

final class PersonalTranslationTests: XCTestCase {
    private func context(_ text: String) -> ActionContext {
        ActionContext(selection: SelectionContext(text: text, sourceApp: AppIdentity(NSRunningApplication.current)))
    }

    // MARK: - Preferences

    func testAutomaticTargetUsesPrimaryUnlessAlreadyPrimary() {
        let prefs = PersonalLanguagePreferences(primary: "zh-Hant", secondary: "en", favorites: ["zh-Hant", "en"])
        XCTAssertEqual(prefs.automaticTarget(for: "en"), "zh-Hant")
        XCTAssertEqual(prefs.automaticTarget(for: "ja"), "zh-Hant")
        XCTAssertEqual(prefs.automaticTarget(for: "zh-Hant"), "en")
    }

    func testPreferencesSanitiseUnknownAndDuplicateCodes() {
        let prefs = PersonalLanguagePreferences(primary: "xx", secondary: "xx", favorites: ["ja", "bogus", "ja", "en"])
        XCTAssertEqual(prefs.primary, "zh-Hant")
        XCTAssertEqual(prefs.secondary, "en")
        XCTAssertEqual(prefs.favorites, ["ja", "en"])
    }

    func testPreferencesNeverUseSameLanguageTwice() {
        let prefs = PersonalLanguagePreferences(primary: "en", secondary: "en", favorites: [])
        XCTAssertEqual(prefs.secondary, "zh-Hant")
        XCTAssertEqual(prefs.favorites, ["en", "zh-Hant"])
    }

    func testLockedTargetWinsUnlessTextIsAlreadyInIt() {
        let prefs = PersonalLanguagePreferences(primary: "zh-Hant", secondary: "en", favorites: [], locked: "en")
        XCTAssertEqual(prefs.automaticTarget(for: "ja"), "en")
        XCTAssertEqual(prefs.automaticTarget(for: "zh-Hant"), "en")
        // Already English: fall back to the automatic pair instead of a no-op.
        XCTAssertEqual(prefs.automaticTarget(for: "en"), "zh-Hant")
        XCTAssertEqual(prefs.targetSummary, "英文")
    }

    func testUnknownLockedLanguageMeansAutomatic() {
        let prefs = PersonalLanguagePreferences(primary: "zh-Hant", secondary: "en", favorites: [], locked: "")
        XCTAssertNil(prefs.locked)
        XCTAssertEqual(prefs.targetSummary, "自動")
        XCTAssertEqual(prefs.automaticTarget(for: "ja"), "zh-Hant")
    }

    func testTitlesShowTheLockedTarget() {
        let locked = PersonalLanguagePreferences(primary: "zh-Hant", secondary: "en", favorites: [], locked: "ja")
        let auto = PersonalLanguagePreferences(primary: "zh-Hant", secondary: "en", favorites: [])
        XCTAssertEqual(TranslateAction.titled("翻譯", preferences: locked), "翻譯 → 日文")
        XCTAssertEqual(TranslateAction.titled("譯後替換", preferences: auto), "譯後替換")
    }

    @MainActor
    func testManageLanguagesRowSitsInTheTranslateToMenu() {
        let manage = ManageLanguagesAction()
        let group = TranslateAction.group()
        let target = TranslateAction(target: PersonalLanguage.named("ja")!)
        let children = group.subActions(in: [group, target, manage]).map(\.id)
        XCTAssertEqual(children, [target.id, manage.id])
        XCTAssertTrue(manage.isEnabled(for: context("anything")))
    }

    @MainActor
    func testProbesNeverTargetOurOwnProcess() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        XCTAssertTrue(MacSelectionMonitor.touchesOwnUI(cocoaPoint: CGPoint(x: -99_999, y: -99_999), pid: ownPID))
        XCTAssertFalse(MacSelectionMonitor.touchesOwnUI(cocoaPoint: CGPoint(x: -99_999, y: -99_999), pid: 1))
    }

    // MARK: - Chinese conversion

    func testSimplifiedToTraditional() {
        XCTAssertEqual(ChineseConverter.toTraditional("软件开发的头发"), "軟件開發的頭髮")
    }

    func testTraditionalToSimplified() {
        XCTAssertEqual(ChineseConverter.toSimplified("軟件開發的頭髮"), "软件开发的头发")
    }

    func testDetectScript() {
        XCTAssertEqual(ChineseConverter.detectScript("这是简体中文"), .simplified)
        XCTAssertEqual(ChineseConverter.detectScript("這是繁體中文"), .traditional)
        XCTAssertNil(ChineseConverter.detectScript("hello"))
    }

    func testContainsHan() {
        XCTAssertTrue(ChineseConverter.containsHan("abc 中 def"))
        XCTAssertFalse(ChineseConverter.containsHan("abc def 123"))
    }

    // MARK: - Language detection

    func testDetectsCommonLanguages() {
        XCTAssertEqual(LanguageDetector.detect("The quick brown fox jumps over the lazy dog."), "en")
        XCTAssertEqual(LanguageDetector.detect("这是一个简体中文的句子，用来测试。"), "zh-Hans")
        XCTAssertEqual(LanguageDetector.detect("這是一個繁體中文的句子，用來測試。"), "zh-Hant")
        XCTAssertEqual(LanguageDetector.detect("これは日本語の文章です。"), "ja")
        XCTAssertEqual(LanguageDetector.detect("Bonjour tout le monde, comment allez-vous aujourd'hui ?"), "fr")
        XCTAssertNil(LanguageDetector.detect("   "))
    }

    // MARK: - Visibility rules

    func testTranslatableRules() {
        XCTAssertTrue(PersonalTextRules.isTranslatable("hello"))
        XCTAssertFalse(PersonalTextRules.isTranslatable("12345 + 6"))
        XCTAssertFalse(PersonalTextRules.isTranslatable("https://example.com/page"))
        XCTAssertFalse(PersonalTextRules.isTranslatable(String(repeating: "a", count: PersonalTextRules.maxTranslateLength + 1)))
    }

    @MainActor
    func testTranslateToHidesWhenTextAlreadyInTarget() {
        let toEnglish = TranslateAction(target: PersonalLanguage.named("en")!)
        XCTAssertFalse(toEnglish.isEnabled(for: context("This sentence is already written in English.")))
        XCTAssertTrue(toEnglish.isEnabled(for: context("這句是繁體中文，需要翻譯。")))
    }

    @MainActor
    func testChineseConvertActionsOnlyOfferUsefulDirection() {
        let toTraditional = ChineseConvertAction(script: .traditional)
        let toSimplified = ChineseConvertAction(script: .simplified)
        XCTAssertTrue(toTraditional.isEnabled(for: context("简体中文")))
        XCTAssertFalse(toSimplified.isEnabled(for: context("简体中文")))
        XCTAssertFalse(toTraditional.isEnabled(for: context("English only")))
        XCTAssertFalse(ChineseConvertAction.group().isEnabled(for: context("English only")))
        XCTAssertTrue(ChineseConvertAction.group().isEnabled(for: context("繁體")))
    }

    @MainActor
    func testChineseConvertPerformReturnsConvertedText() async throws {
        let result = try await ChineseConvertAction(script: .traditional).perform(context("简体"))
        guard case .text(let text) = result else { return XCTFail("expected text, got \(result)") }
        XCTAssertEqual(text, "簡體")
    }

    // MARK: - Translator

    @MainActor
    func testTranslatorConvertsBetweenChineseScriptsWithoutFramework() async throws {
        let outcome = try await OfflineTranslator.shared.translate("简体中文", source: "zh-Hans", target: "zh-Hant")
        XCTAssertEqual(outcome.text, "簡體中文")
    }

    @MainActor
    func testTranslatorRejectsSameLanguage() async {
        do {
            _ = try await OfflineTranslator.shared.translate("hello", source: "en", target: "en")
            XCTFail("expected sameLanguage")
        } catch let error as OfflineTranslatorError {
            XCTAssertEqual(error, .sameLanguage("en"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    /// Exercises the real on-device model; skipped where the English → Traditional Chinese pack is absent.
    @MainActor
    func testOfflineEnglishToTraditionalChinese() async throws {
        guard await OfflineTranslator.shared.status(source: "en", target: "zh-Hant") == .installed else {
            throw XCTSkip("en → zh-Hant language pack not installed")
        }
        let outcome = try await OfflineTranslator.shared.translate("Good morning\n\nThank you", source: "en", target: "zh-Hant")
        let lines = outcome.text.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3, "line structure should survive translation")
        XCTAssertTrue(lines[1].isEmpty)
        XCTAssertTrue(ChineseConverter.containsHan(outcome.text))
    }

    func testTidyPunctuationRemovesSpacesAroundCJKPunctuation() {
        XCTAssertEqual(OfflineTranslator.tidyPunctuation("感覺平靜 、 快速和私密 。", target: "zh-Hant"), "感覺平靜、快速和私密。")
        XCTAssertEqual(OfflineTranslator.tidyPunctuation("「 你好 」", target: "zh-Hant"), "「你好」")
        XCTAssertEqual(OfflineTranslator.tidyPunctuation("Hello , world .", target: "en"), "Hello , world .")
    }

    // MARK: - Prefetch and replace

    @MainActor
    func testPrefetchedOutcomeIsReused() async throws {
        let prefetcher = TranslationPrefetcher()
        prefetcher.prefetch("简体中文", target: "zh-Hant")
        let first = try await prefetcher.outcome(for: "简体中文", target: "zh-Hant")
        let second = try await prefetcher.outcome(for: "简体中文", target: "zh-Hant")
        XCTAssertEqual(first.text, "簡體中文")
        XCTAssertEqual(first, second)
    }

    @MainActor
    func testPrefetchSkipsLongText() async throws {
        let prefetcher = TranslationPrefetcher()
        let long = String(repeating: "简", count: TranslationPrefetcher.maxPrefetchLength + 1)
        prefetcher.prefetch(long, target: "zh-Hant")
        // Still answers on demand.
        let outcome = try await prefetcher.outcome(for: long, target: "zh-Hant")
        XCTAssertEqual(outcome.text.count, long.count)
    }

    @MainActor
    func testTranslateReplaceOnlyForReplaceableSelections() {
        let action = TranslateReplaceAction()
        let readOnly = ActionContext(selection: SelectionContext(text: "Hello there", isEditable: false))
        let editable = ActionContext(selection: SelectionContext(text: "Hello there", isEditable: true))
        XCTAssertFalse(action.isEnabled(for: readOnly))
        XCTAssertTrue(action.isEnabled(for: editable))
        XCTAssertTrue(action is any PasteRequiringAction)
        XCTAssertEqual(action.chrome.requiresLiveSelection, true)
    }

    @MainActor
    func testLaterAdditionsSlotInAfterTheirNeighbour() {
        let order = ["builtin.copy", TranslateAction.automaticID, "builtin.search"]
        XCTAssertEqual(
            PersonalFeatures.insertingLaterAdditions(into: order),
            ["builtin.copy", TranslateAction.automaticID, "personal.translateReplace", "builtin.search"]
        )
        let already = PersonalFeatures.insertingLaterAdditions(into: order)
        XCTAssertEqual(PersonalFeatures.insertingLaterAdditions(into: already), already)
        XCTAssertEqual(PersonalFeatures.insertingLaterAdditions(into: []), [])
    }

    // MARK: - History

    @MainActor
    func testHistoryDeduplicatesAndPersists() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("personal-history-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PersonalHistoryStore(fileURL: url)
        store.record(kind: .translation, original: "hello", result: "你好", source: "en", target: "zh-Hant", app: "Notes")
        store.record(kind: .translation, original: "world", result: "世界", source: "en", target: "zh-Hant", app: "Notes")
        store.toggleStar(try XCTUnwrap(store.entries.first { $0.original == "world" }).id)
        store.record(kind: .translation, original: "hello", result: "你好", source: "en", target: "zh-Hant", app: "Safari")
        XCTAssertEqual(store.entries.map(\.original), ["hello", "world"])
        XCTAssertEqual(store.entries[0].app, "Safari")

        let reloaded = PersonalHistoryStore(fileURL: url)
        reloaded.loadIfNeeded()
        XCTAssertEqual(reloaded.entries.count, 2)
        XCTAssertTrue(reloaded.entries.contains { $0.original == "world" && $0.starred })

        reloaded.clearAll(keepingStarred: true)
        XCTAssertEqual(reloaded.entries.map(\.original), ["world"])
    }

    func testCSVFieldEscaping() {
        XCTAssertEqual(PersonalHistoryStore.csvField("plain"), "plain")
        XCTAssertEqual(PersonalHistoryStore.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(PersonalHistoryStore.csvField("say \"hi\""), "\"say \"\"hi\"\"\"")
    }
}
