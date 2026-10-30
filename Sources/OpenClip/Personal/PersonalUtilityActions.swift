// PersonalUtilityActions.swift
// OpenClip
//
// Offline system-framework actions: read aloud, open an address in Maps, call a phone number.
// Each one only appears when the selection fits (context-aware bar).
import AppKit
import AVFoundation
import Core

enum PersonalUtilityActions {
    @MainActor
    static func all() -> [any Action] {
        [SpeakAction(), MapsAction(), CallAction()]
    }
}

/// Owns the synthesizer so speech survives the popup closing; a second click stops it.
@MainActor
final class PersonalSpeech {
    static let shared = PersonalSpeech()

    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        if let voice = Self.voice(for: LanguageDetector.detect(text)) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    /// Traditional Chinese is read in Cantonese, Simplified in Mandarin. Installed voices are matched
    /// exactly first: `AVSpeechSynthesisVoice(language:)` falls back to the system's Chinese voice for
    /// every zh-* tag, which would read Simplified Chinese in Cantonese.
    static func voice(for code: String?) -> AVSpeechSynthesisVoice? {
        guard let code else { return nil }
        let candidates: [String]
        switch code {
        case "zh-Hant": candidates = ["yue-HK", "zh-HK", "zh-TW", "zh-CN"]
        case "zh-Hans": candidates = ["zh-CN", "zh-TW"]
        case "en": candidates = ["en-US", "en-GB"]
        case "ja": candidates = ["ja-JP"]
        case "ko": candidates = ["ko-KR"]
        default: candidates = [code]
        }
        let installed = AVSpeechSynthesisVoice.speechVoices()
        for identifier in candidates {
            let matches = installed.filter { $0.language == identifier }
            if let best = matches.max(by: { $0.quality.rawValue < $1.quality.rawValue }) { return best }
        }
        return candidates.lazy.compactMap { AVSpeechSynthesisVoice(language: $0) }.first
    }
}

struct SpeakAction: ConfigurableAction {
    let id = "personal.speak"
    var title: String { "朗讀" }
    let icon = ActionIcon.symbol("speaker.wave.2")
    var keywords: [String] { ["speak", "read aloud", "tts", "朗讀", "讀出"] }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        let text = context.selection.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 20_000 && text.unicodeScalars.contains { $0.properties.isAlphabetic }
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        let speech = PersonalSpeech.shared
        if speech.isSpeaking {
            speech.stop()
            return .toast(StatusFeedback(message: "已停止朗讀", style: .info, symbolName: "speaker.slash"))
        }
        speech.speak(context.selection.text)
        return .toast(StatusFeedback(message: "朗讀中・再撳一次停止", style: .info, symbolName: "speaker.wave.2"))
    }
}

struct MapsAction: ConfigurableAction {
    let id = "personal.maps"
    var title: String { "地圖" }
    let icon = ActionIcon.symbol("map")
    var keywords: [String] { ["map", "maps", "address", "地圖", "地址"] }

    static func address(in text: String) -> String? {
        guard text.count <= 500 else { return nil }
        return NativeContentDetector.detect(text, type: .address).addresses.first?.text
    }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        Self.address(in: context.selection.text) != nil
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        guard let address = Self.address(in: context.selection.text),
              let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(query)") else { return .none }
        return .openURL(url)
    }
}

struct CallAction: ConfigurableAction {
    let id = "personal.call"
    var title: String { "撥打" }
    let icon = ActionIcon.symbol("phone")
    var keywords: [String] { ["call", "phone", "facetime", "撥打", "電話"] }

    static func phoneNumber(in text: String) -> String? {
        guard text.count <= 60 else { return nil }
        return NativeContentDetector.detect(text, type: .phone).phones.first
    }

    @MainActor
    func isEnabled(for context: ActionContext) -> Bool {
        Self.phoneNumber(in: context.selection.text) != nil
    }

    @MainActor
    func perform(_ context: ActionContext) async throws -> ActionResult {
        guard let number = Self.phoneNumber(in: context.selection.text) else { return .none }
        let digits = number.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return .none }
        return .openURL(url)
    }
}
