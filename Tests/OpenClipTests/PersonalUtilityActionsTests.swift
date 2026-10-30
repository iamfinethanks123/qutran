import XCTest
import AppKit
import AVFoundation
@testable import OpenClip
@testable import Core

final class PersonalUtilityActionsTests: XCTestCase {
    private func context(_ text: String) -> ActionContext {
        ActionContext(selection: SelectionContext(text: text, sourceApp: AppIdentity(NSRunningApplication.current)))
    }

    @MainActor
    func testSpeakNeedsLetters() {
        XCTAssertTrue(SpeakAction().isEnabled(for: context("Hello there")))
        XCTAssertFalse(SpeakAction().isEnabled(for: context("1234 !!")))
    }

    @MainActor
    func testCallOnlyForPhoneNumbers() async throws {
        XCTAssertTrue(CallAction().isEnabled(for: context("+1 (415) 555-0123")))
        XCTAssertFalse(CallAction().isEnabled(for: context("just some words")))
        let result = try await CallAction().perform(context("+1 (415) 555-0123"))
        guard case .openURL(let url) = result else { return XCTFail("expected openURL, got \(result)") }
        XCTAssertEqual(url.absoluteString, "tel:+14155550123")
    }

    @MainActor
    func testMapsOnlyForAddresses() async throws {
        let address = "1 Infinite Loop, Cupertino, CA 95014"
        XCTAssertTrue(MapsAction().isEnabled(for: context(address)))
        XCTAssertFalse(MapsAction().isEnabled(for: context("no address here")))
        let result = try await MapsAction().perform(context(address))
        guard case .openURL(let url) = result else { return XCTFail("expected openURL, got \(result)") }
        XCTAssertEqual(url.scheme, "maps")
    }

    @MainActor
    func testVoicePrefersCantoneseForTraditionalChinese() throws {
        let voice = try XCTUnwrap(PersonalSpeech.voice(for: "zh-Hant"))
        XCTAssertTrue(["yue-HK", "zh-HK", "zh-TW", "zh-CN"].contains(voice.language), voice.language)
        if AVSpeechSynthesisVoice.speechVoices().contains(where: { $0.language == "zh-CN" }) {
            XCTAssertEqual(PersonalSpeech.voice(for: "zh-Hans")?.language, "zh-CN")
        }
        XCTAssertNil(PersonalSpeech.voice(for: nil))
    }

    @MainActor
    func testExtraAIPresetsDoNotCollideWithDefaults() {
        let defaults = Set(AIServiceManager.defaultPresets.map(\.id))
        let extras = PersonalFeatures.extraAIPresets.map(\.id)
        XCTAssertEqual(Set(extras).count, extras.count)
        XCTAssertTrue(defaults.isDisjoint(with: extras))
    }

    @MainActor
    func testDefaultActionOrderHasNoDuplicates() {
        XCTAssertEqual(Set(PersonalFeatures.defaultActionOrder).count, PersonalFeatures.defaultActionOrder.count)
        XCTAssertEqual(PersonalFeatures.defaultActionOrder.prefix(2), ["builtin.copy", TranslateAction.automaticID])
    }
}
