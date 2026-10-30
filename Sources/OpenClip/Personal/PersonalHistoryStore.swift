// PersonalHistoryStore.swift
// OpenClip
//
// Local history of translations and dictionary lookups ("vocabulary book"), persisted as JSON in
// ~/.openclip/personal/history.json. Nothing leaves the machine.
import Foundation
import Combine
import Core

struct PersonalHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case translation
        case lookup
    }

    var id: UUID
    var kind: Kind
    var original: String
    var result: String
    var source: String?
    var target: String?
    var app: String?
    var date: Date
    var starred: Bool
}

@MainActor
final class PersonalHistoryStore: ObservableObject {
    static let shared = PersonalHistoryStore()

    static let maxEntries = 2_000
    /// Longer selections are not worth keeping as vocabulary.
    static let maxRecordedLength = 2_000

    @Published private(set) var entries: [PersonalHistoryEntry] = []

    private let fileURL: URL
    private var loaded = false

    init(fileURL: URL = URL(fileURLWithPath: ("~/.openclip/personal/history.json" as NSString).expandingTildeInPath)) {
        self.fileURL = fileURL
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            entries = try decoder.decode([PersonalHistoryEntry].self, from: data)
        } catch {
            Log.personal.error("History decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func record(kind: PersonalHistoryEntry.Kind, original: String, result: String, source: String?, target: String?, app: String?) {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxRecordedLength else { return }
        loadIfNeeded()
        // Re-looking up the same text moves it to the top instead of duplicating it.
        var starred = false
        if let index = entries.firstIndex(where: { $0.original == trimmed && $0.target == target && $0.kind == kind }) {
            starred = entries[index].starred
            entries.remove(at: index)
        }
        let entry = PersonalHistoryEntry(
            id: UUID(), kind: kind, original: trimmed,
            result: result.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source, target: target, app: app, date: Date(), starred: starred
        )
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        save()
    }

    func toggleStar(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].starred.toggle()
        save()
    }

    func delete(_ ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func clearAll(keepingStarred: Bool) {
        entries.removeAll { !keepingStarred || !$0.starred }
        save()
    }

    /// CSV with a UTF-8 BOM so Excel and Numbers open the Chinese text correctly.
    func csv(for subset: [PersonalHistoryEntry]? = nil) -> String {
        let formatter = ISO8601DateFormatter()
        let rows = (subset ?? entries).map { entry in
            [
                formatter.string(from: entry.date),
                entry.kind.rawValue,
                entry.source.map(PersonalLanguage.displayName) ?? "",
                entry.target.map(PersonalLanguage.displayName) ?? "",
                entry.original,
                entry.result,
                entry.app ?? "",
                entry.starred ? "★" : "",
            ].map(Self.csvField).joined(separator: ",")
        }
        let header = ["時間", "類型", "原文語言", "譯文語言", "原文", "譯文", "來源 App", "星號"].joined(separator: ",")
        return "\u{FEFF}" + ([header] + rows).joined(separator: "\r\n")
    }

    nonisolated static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            Log.personal.error("History save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
