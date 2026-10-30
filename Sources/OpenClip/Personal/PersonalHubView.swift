// PersonalHubView.swift
// OpenClip
//
// SwiftUI content of the personal hub: quick translate, vocabulary book and language settings.
// Warm cream canvas, ivory cards with soft shadows, serif display type and a single bronze accent.
import SwiftUI
import AppKit
import Translation
import UniformTypeIdentifiers
import Core

// MARK: - Theme

enum HubTheme {
    static let canvas = Color(red: 0.973, green: 0.957, blue: 0.925)       // #F8F4EC cream
    static let sidebar = Color(red: 0.941, green: 0.918, blue: 0.875)      // #F0EADF
    static let card = Color(red: 1.0, green: 0.996, blue: 0.984)           // #FFFEFB ivory
    static let cardTint = Color(red: 0.984, green: 0.969, blue: 0.937)     // #FBF7EF
    static let ink = Color(red: 0.165, green: 0.141, blue: 0.122)          // #2A241F
    static let inkSecondary = ink.opacity(0.62)
    static let inkTertiary = ink.opacity(0.38)
    static let hairline = Color(red: 0.851, green: 0.820, blue: 0.765)     // #D9D1C3
    static let accent = Color(red: 0.604, green: 0.463, blue: 0.267)       // #9A7644 bronze
    static let accentSoft = accent.opacity(0.12)
    static let success = Color(red: 0.353, green: 0.506, blue: 0.333)      // #5A8155 sage

    static let nsCanvas = NSColor(red: 0.973, green: 0.957, blue: 0.925, alpha: 1)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
}

private struct HubCard<Content: View>: View {
    var tint: Color = HubTheme.card
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint)
                    .shadow(color: Color(red: 0.42, green: 0.33, blue: 0.20).opacity(0.07), radius: 18, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(HubTheme.hairline.opacity(0.7), lineWidth: 0.5)
            )
    }
}

private struct PaneHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HubTheme.display(28))
                    .foregroundStyle(HubTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(HubTheme.inkSecondary)
            }
            Spacer(minLength: 16)
            trailing
        }
    }
}

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(HubTheme.inkTertiary)
            .padding(.leading, 4)
    }
}

/// Small circular icon button used in card footers and headers.
private struct RoundIconButton: View {
    let symbol: String
    let help: String
    var prominent = false
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(prominent ? HubTheme.accent : (hovering ? HubTheme.ink : HubTheme.inkSecondary))
                .frame(width: 30, height: 30)
                .background(Circle().fill(hovering ? HubTheme.accentSoft : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Capsule menu for picking a language; the label reads like text, not a control.
private struct LanguagePill: View {
    let label: String
    let selected: String?
    let automaticTitle: String?
    var onSelect: (String?) -> Void

    var body: some View {
        Menu {
            if let automaticTitle {
                Button { onSelect(nil) } label: { checkmarked(automaticTitle, selected == nil) }
                Divider()
            }
            ForEach(PersonalLanguage.all) { language in
                Button { onSelect(language.code) } label: { checkmarked(language.name, selected == language.code) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HubTheme.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(HubTheme.inkTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Capsule().fill(HubTheme.card))
            .overlay(Capsule().strokeBorder(HubTheme.hairline, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private func checkmarked(_ title: String, _ on: Bool) -> some View {
        if on { Label(title, systemImage: "checkmark") } else { Text(title) }
    }
}

// MARK: - Root

struct PersonalHubView: View {
    @ObservedObject var model: PersonalHubModel

    var body: some View {
        HStack(spacing: 0) {
            HubSidebar(model: model)
            Rectangle().fill(HubTheme.hairline.opacity(0.6)).frame(width: 0.5)
            Group {
                switch model.section {
                case .translate: QuickTranslatePane(model: model)
                case .history: HistoryPane()
                case .languages: LanguagesPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HubTheme.canvas)
        }
        .ignoresSafeArea()
        .frame(minWidth: 720, minHeight: 500)
        .environment(\.colorScheme, .light)
        .tint(HubTheme.accent)
    }
}

private struct HubSidebar: View {
    @ObservedObject var model: PersonalHubModel
    @State private var modelReady: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("OpenClip")
                    .font(HubTheme.display(19))
                    .foregroundStyle(HubTheme.ink)
                Text("離線 · 本機 · 私隱")
                    .font(.system(size: 11))
                    .tracking(0.6)
                    .foregroundStyle(HubTheme.inkTertiary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 58)
            .padding(.bottom, 26)

            VStack(spacing: 4) {
                ForEach(PersonalHubSection.allCases) { section in
                    SidebarItem(section: section, isSelected: model.section == section) {
                        withAnimation(.easeOut(duration: 0.15)) { model.section = section }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(modelReady == false ? HubTheme.inkTertiary : HubTheme.success)
                    .frame(width: 6, height: 6)
                Text(modelReady == false ? "離線模型未就緒" : "離線模型已就緒")
                    .font(.system(size: 11))
                    .foregroundStyle(HubTheme.inkSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(HubTheme.sidebar)
        .task {
            let prefs = PersonalLanguagePreferences()
            modelReady = await OfflineTranslator.pairStatus(source: prefs.secondary, target: prefs.primary) == .installed
        }
    }
}

private struct SidebarItem: View {
    let section: PersonalHubSection
    let isSelected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? HubTheme.accent : HubTheme.inkSecondary)
                    .frame(width: 18)
                Text(section.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? HubTheme.ink : HubTheme.inkSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? HubTheme.card : (hovering ? HubTheme.card.opacity(0.5) : .clear))
                    .shadow(color: .black.opacity(isSelected ? 0.05 : 0), radius: 4, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Quick translate

struct QuickTranslatePane: View {
    @ObservedObject var model: PersonalHubModel

    @State private var input = ""
    @State private var output = ""
    @State private var source: String?
    @State private var target: String?
    @State private var outcome: TranslationOutcome?
    @State private var message: String?
    @State private var isWorking = false
    @State private var saved = false
    @State private var copied = false
    @State private var work: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PaneHeader(title: "翻譯", subtitle: "完全喺呢部 Mac 上運行，唔需要網絡") { EmptyView() }
            VStack(spacing: 12) {
                languageBar
                HStack(spacing: 16) {
                    inputCard
                    outputCard
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 52)
        .padding(.bottom, 28)
        .onAppear(perform: consumePendingInput)
        .onChange(of: model.pendingInput) { consumePendingInput() }
        .onChange(of: model.focusRequest) { inputFocused = true }
        .onChange(of: input) { scheduleTranslation(delay: 0.35) }
        .onChange(of: source) { scheduleTranslation(delay: 0) }
        .onChange(of: target) { scheduleTranslation(delay: 0) }
        .task { inputFocused = true }
    }

    /// Each pill sits above its own card; swap closes the source row, next to the target pill.
    private var languageBar: some View {
        HStack(spacing: 16) {
            HStack {
                LanguagePill(label: sourceLabel, selected: source, automaticTitle: "自動偵測") { source = $0 }
                Spacer()
                Button(action: swap) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(outcome == nil ? HubTheme.inkTertiary : HubTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(HubTheme.card))
                        .overlay(Circle().strokeBorder(HubTheme.hairline, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(outcome == nil)
                .help("對調語言")
                .accessibilityLabel("對調語言")
            }
            HStack {
                LanguagePill(label: targetLabel, selected: target, automaticTitle: "自動") { target = $0 }
                Spacer()
            }
        }
    }

    private var sourceLabel: String {
        if let source { return PersonalLanguage.displayName(source) }
        if let detected = outcome?.source { return "\(PersonalLanguage.displayName(detected))（偵測）" }
        return "自動偵測"
    }

    private var targetLabel: String {
        if let target { return PersonalLanguage.displayName(target) }
        if let resolved = outcome?.target { return PersonalLanguage.displayName(resolved) }
        return "自動"
    }

    private var inputCard: some View {
        HubCard {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("輸入或貼上文字…")
                            .font(.system(size: 16))
                            .foregroundStyle(HubTheme.inkTertiary)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $input)
                        .font(.system(size: 16))
                        .foregroundStyle(HubTheme.ink)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                        .focused($inputFocused)
                }
                footer {
                    Text("\(input.count) 字元")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(HubTheme.inkTertiary)
                    Spacer()
                    RoundIconButton(symbol: "doc.on.clipboard", help: "貼上") {
                        if let text = NSPasteboard.general.string(forType: .string) { input = text }
                    }
                    RoundIconButton(symbol: "xmark", help: "清除") { input = "" }
                        .opacity(input.isEmpty ? 0.35 : 1)
                        .disabled(input.isEmpty)
                }
            }
        }
    }

    private var outputCard: some View {
        HubCard(tint: HubTheme.cardTint) {
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        if let message {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(HubTheme.accent)
                                Text(message)
                                    .foregroundStyle(HubTheme.inkSecondary)
                            }
                            .font(.system(size: 14))
                        } else if output.isEmpty {
                            Text("譯文會喺呢度出現")
                                .font(.system(size: 16))
                                .foregroundStyle(HubTheme.inkTertiary)
                        } else {
                            Text(output)
                                .font(.system(size: 17, design: .serif))
                                .foregroundStyle(HubTheme.ink)
                                .lineSpacing(5)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 25)
                    .padding(.vertical, 22)
                }
                .scrollIndicators(.never)
                footer {
                    if isWorking {
                        ProgressView().controlSize(.mini)
                    } else if let outcome {
                        Text("\(PersonalLanguage.displayName(outcome.source))  →  \(PersonalLanguage.displayName(outcome.target))")
                            .font(.system(size: 11))
                            .foregroundStyle(HubTheme.inkTertiary)
                    }
                    Spacer()
                    Group {
                        RoundIconButton(symbol: "speaker.wave.2", help: "朗讀") { PersonalSpeech.shared.speak(output) }
                        RoundIconButton(symbol: saved ? "bookmark.fill" : "bookmark", help: "加入生字簿", prominent: saved) { save() }
                        RoundIconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: "複製", prominent: copied) { copy() }
                    }
                    .opacity(output.isEmpty ? 0.35 : 1)
                    .disabled(output.isEmpty)
                }
            }
        }
        .background(
            Button("", action: copy).keyboardShortcut(.return, modifiers: .command).hidden()
        )
    }

    private func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(HubTheme.hairline.opacity(0.5)).frame(height: 0.5).padding(.horizontal, 18)
            HStack(spacing: 2, content: content)
                .padding(.leading, 22)
                .padding(.trailing, 12)
                .frame(height: 46)
        }
    }

    private func consumePendingInput() {
        guard let pending = model.pendingInput else { return }
        model.pendingInput = nil
        input = pending
    }

    private func scheduleTranslation(delay: Double) {
        work?.cancel()
        saved = false
        copied = false
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            outcome = nil
            message = nil
            isWorking = false
            return
        }
        work = Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            isWorking = true
            defer { if !Task.isCancelled { isWorking = false } }
            do {
                let result = try await OfflineTranslator.shared.translate(text, source: source, target: target)
                guard !Task.isCancelled else { return }
                outcome = result
                output = result.text
                message = nil
            } catch {
                guard !Task.isCancelled else { return }
                output = ""
                outcome = nil
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func swap() {
        guard let outcome else { return }
        source = outcome.target
        target = outcome.source
        input = output
    }

    private func save() {
        guard let outcome, !output.isEmpty else { return }
        PersonalHistoryStore.shared.record(kind: .translation, original: input, result: output,
                                           source: outcome.source, target: outcome.target, app: "快速翻譯")
        saved = true
    }

    private func copy() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        save()
        copied = true
    }
}

// MARK: - History

struct HistoryPane: View {
    @ObservedObject private var store = PersonalHistoryStore.shared
    @State private var query = ""
    @State private var starredOnly = false
    @State private var confirmClear = false

    private var filtered: [PersonalHistoryEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return store.entries.filter { entry in
            (!starredOnly || entry.starred)
                && (needle.isEmpty || entry.original.localizedCaseInsensitiveContains(needle)
                    || entry.result.localizedCaseInsensitiveContains(needle))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaneHeader(title: "生字簿", subtitle: store.entries.isEmpty ? "翻譯過嘅文字會記錄喺度" : "共 \(store.entries.count) 條記錄") {
                HStack(spacing: 6) {
                    RoundIconButton(symbol: "square.and.arrow.up", help: "匯出 CSV", action: exportCSV)
                        .disabled(store.entries.isEmpty)
                    Menu {
                        Button("清除冇星號嘅記錄") { store.clearAll(keepingStarred: true) }
                        Button("清除全部…", role: .destructive) { confirmClear = true }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(HubTheme.inkSecondary)
                            .frame(width: 30, height: 30)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("清除")
                    .disabled(store.entries.isEmpty)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HubTheme.inkTertiary)
                    TextField("搜尋原文或譯文", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .foregroundStyle(HubTheme.ink)
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(HubTheme.card))
                .overlay(Capsule().strokeBorder(HubTheme.hairline, lineWidth: 0.5))

                FilterToggle(starredOnly: $starredOnly)
            }

            if store.entries.isEmpty {
                emptyState(symbol: "book.closed", title: "生字簿仲係空嘅", detail: "喺任何 App 揀字翻譯，或者喺翻譯頁撳書籤，就會記錄喺度。")
            } else if filtered.isEmpty {
                emptyState(symbol: "magnifyingglass", title: "搵唔到相符嘅記錄", detail: "試吓其他關鍵字。")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { entry in
                            HistoryCard(entry: entry) { store.toggleStar(entry.id) }
                                .contextMenu { contextMenu(for: entry) }
                        }
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.never)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 52)
        .padding(.bottom, 20)
        .confirmationDialog("清除全部記錄？", isPresented: $confirmClear) {
            Button("清除全部", role: .destructive) { store.clearAll(keepingStarred: false) }
        } message: {
            Text("連星號記錄都會刪除，冇得復原。")
        }
        .onAppear { store.loadIfNeeded() }
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(HubTheme.accent.opacity(0.7))
            Text(title)
                .font(HubTheme.display(18))
                .foregroundStyle(HubTheme.ink)
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(HubTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contextMenu(for entry: PersonalHistoryEntry) -> some View {
        Button("複製譯文") { copy(entry.result) }
        Button("複製原文") { copy(entry.original) }
        Button("朗讀原文") { PersonalSpeech.shared.speak(entry.original) }
        Button("再翻譯") { PersonalHubWindowController.show(.translate, input: entry.original) }
        Divider()
        Button(entry.starred ? "取消星號" : "加星號") { store.toggleStar(entry.id) }
        Button("刪除", role: .destructive) { store.delete([entry.id]) }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "生字簿.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.csv(for: filtered).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

private struct FilterToggle: View {
    @Binding var starredOnly: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment("全部", isOn: !starredOnly) { starredOnly = false }
            segment("★ 星號", isOn: starredOnly) { starredOnly = true }
        }
        .padding(3)
        .background(Capsule().fill(HubTheme.sidebar))
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? HubTheme.ink : HubTheme.inkSecondary)
                .padding(.horizontal, 13)
                .frame(height: 28)
                .background(Capsule().fill(isOn ? HubTheme.card : .clear).shadow(color: .black.opacity(isOn ? 0.06 : 0), radius: 2, y: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryCard: View {
    let entry: PersonalHistoryEntry
    var toggleStar: () -> Void

    var body: some View {
        HubCard(radius: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.original)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(HubTheme.ink)
                        .lineLimit(2)
                    Text(entry.result)
                        .font(.system(size: 14.5, design: .serif))
                        .foregroundStyle(HubTheme.inkSecondary)
                        .lineLimit(3)
                    Text(meta)
                        .font(.system(size: 10.5))
                        .tracking(0.3)
                        .foregroundStyle(HubTheme.inkTertiary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Button(action: toggleStar) {
                    Image(systemName: entry.starred ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundStyle(entry.starred ? HubTheme.accent : HubTheme.inkTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(entry.starred ? "取消星號" : "加星號")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private var meta: String {
        var parts: [String] = []
        if let source = entry.source, let target = entry.target {
            parts.append("\(PersonalLanguage.displayName(source)) → \(PersonalLanguage.displayName(target))")
        }
        if let app = entry.app, !app.isEmpty { parts.append(app) }
        parts.append(entry.date.formatted(.relative(presentation: .named)))
        return parts.joined(separator: "  ·  ")
    }
}

// MARK: - Languages

@MainActor
final class PersonalLanguageSettingsModel: ObservableObject {
    private let store: any SettingsStore

    @Published var primary: String { didSet { persist() } }
    @Published var secondary: String { didSet { persist() } }
    @Published var favorites: [String] { didSet { persist() } }
    @Published var statuses: [String: LanguagePairStatus] = [:]

    init(store: any SettingsStore = DefaultSettingsStore.shared) {
        self.store = store
        let prefs = PersonalLanguagePreferences(settingsStore: store)
        primary = prefs.primary
        secondary = prefs.secondary
        favorites = prefs.favorites
    }

    private func persist() {
        store.set(.personalPrimaryLanguage, value: primary)
        store.set(.personalSecondaryLanguage, value: secondary)
        store.set(.personalFavoriteLanguages, value: favorites)
    }

    func toggleFavorite(_ code: String) {
        if let index = favorites.firstIndex(of: code) {
            guard favorites.count > 1 else { return }
            favorites.remove(at: index)
        } else {
            favorites.append(code)
        }
    }

    /// Language packs worth having: primary paired with every other favourite and the secondary.
    var packLanguages: [String] {
        var codes = favorites
        if !codes.contains(secondary) { codes.append(secondary) }
        return codes.filter { $0 != primary && !($0.hasPrefix("zh") && primary.hasPrefix("zh")) }
    }

    func refreshStatuses() async {
        var result: [String: LanguagePairStatus] = [:]
        for code in packLanguages {
            result[code] = await OfflineTranslator.pairStatus(source: code, target: primary)
        }
        statuses = result
    }
}

struct LanguagesPane: View {
    @StateObject private var settings = PersonalLanguageSettingsModel()
    @State private var downloadConfiguration: TranslationSession.Configuration?

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PaneHeader(title: "語言", subtitle: "設定一鍵翻譯同「翻譯為…」選單") { EmptyView() }

                section("一鍵翻譯", footnote: "揀咗嘅文字會翻做主語言；如果本身已經係主語言，就翻做副語言。") {
                    VStack(spacing: 0) {
                        settingRow("主語言", detail: "大部分文字會翻做呢個語言") {
                            LanguagePill(label: PersonalLanguage.displayName(settings.primary), selected: settings.primary, automaticTitle: nil) {
                                if let code = $0 { settings.primary = code }
                            }
                        }
                        rowDivider
                        settingRow("副語言", detail: "原文已經係主語言時使用") {
                            LanguagePill(label: PersonalLanguage.displayName(settings.secondary), selected: settings.secondary, automaticTitle: nil) {
                                if let code = $0, code != settings.primary { settings.secondary = code }
                            }
                        }
                    }
                }

                section("翻譯為… 選單", footnote: "數字代表喺選單入面嘅次序。") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(PersonalLanguage.all) { language in
                            LanguageChip(
                                language: language,
                                order: settings.favorites.firstIndex(of: language.code).map { $0 + 1 }
                            ) {
                                withAnimation(.easeOut(duration: 0.12)) { settings.toggleFavorite(language.code) }
                            }
                        }
                    }
                    .padding(16)
                }

                section("離線語言包", footnote: "下載後就可以完全離線翻譯。簡體 ⇄ 繁體用系統內置轉換，唔使語言包。") {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.packLanguages.enumerated()), id: \.element) { index, code in
                            if index > 0 { rowDivider }
                            LanguagePackRow(
                                source: PersonalLanguage.displayName(code),
                                target: PersonalLanguage.displayName(settings.primary),
                                status: settings.statuses[code]
                            ) {
                                downloadConfiguration = TranslationSession.Configuration(
                                    source: Locale.Language(identifier: code),
                                    target: Locale.Language(identifier: settings.primary)
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 52)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.never)
        .task(id: "\(settings.primary)|\(settings.packLanguages.joined(separator: ","))") {
            await settings.refreshStatuses()
        }
        .translationTask(downloadConfiguration) { session in
            // The session is only used here, before the closure returns; the framework hands it over
            // without a Sendable conformance.
            nonisolated(unsafe) let session = session
            try? await session.prepareTranslation()
            await settings.refreshStatuses()
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(HubTheme.hairline.opacity(0.5)).frame(height: 0.5).padding(.leading, 20)
    }

    private func section<Content: View>(_ title: String, footnote: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            HubCard(radius: 16) { content() }
            Text(footnote)
                .font(.system(size: 11.5))
                .foregroundStyle(HubTheme.inkTertiary)
                .padding(.leading, 4)
        }
    }

    private func settingRow<Control: View>(_ title: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(HubTheme.ink)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(HubTheme.inkTertiary)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct LanguageChip: View {
    let language: PersonalLanguage
    let order: Int?
    var action: () -> Void
    @State private var hovering = false

    private var isOn: Bool { order != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(language.name)
                    .font(.system(size: 12.5, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? HubTheme.ink : HubTheme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let order {
                    Text("\(order)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(HubTheme.card)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(HubTheme.accent))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(isOn ? HubTheme.accentSoft : (hovering ? HubTheme.sidebar : HubTheme.cardTint))
            )
            .overlay(Capsule().strokeBorder(isOn ? HubTheme.accent.opacity(0.35) : HubTheme.hairline.opacity(0.6), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(language.name)
        .accessibilityValue(isOn ? "已選" : "未選")
    }
}

private struct LanguagePackRow: View {
    let source: String
    let target: String
    let status: LanguagePairStatus?
    var download: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(source)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(HubTheme.ink)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HubTheme.inkTertiary)
            Text(target)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(HubTheme.ink)
            Spacer()
            switch status {
            case .installed:
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("已下載")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(HubTheme.success)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(HubTheme.success.opacity(0.1)))
            case .downloadable:
                Button(action: download) {
                    Text("下載")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HubTheme.card)
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background(Capsule().fill(HubTheme.accent))
                }
                .buttonStyle(.plain)
            case .unsupported:
                Text("唔支援")
                    .font(.system(size: 12))
                    .foregroundStyle(HubTheme.inkTertiary)
            case nil:
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }
}
