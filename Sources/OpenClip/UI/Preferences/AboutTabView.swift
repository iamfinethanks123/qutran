// AboutTabView.swift
// OpenClip
//
// The About preferences tab: app identity, version, software updates, links, and diagnostics.
// Styled with inset SettingsCards (outside headers, rounded cards, inset hairline dividers).

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core

@MainActor
struct AboutTab: View {
    @State private var isExporting = false
    @ObservedObject private var extensionUpdateManager = ExtensionUpdateManager.shared
    @ObservedObject private var updateManager = AppUpdateManager.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Identity block
                identityBlock

                SettingsCard("Extension Updates") {
                    SettingsToggleRow(
                        title: "Automatically Update Extensions",
                        isOn: $extensionUpdateManager.automaticallyUpdatesExtensions
                    )
                }

                // Credits: Qutran is built on the open-source OpenClip project (AGPL-3.0).
                SettingsCard("致謝") {
                    linkRow("基於 OpenClip 開源項目", systemImage: "chevron.left.forwardslash.chevron.right", url: "https://github.com/ganeshmshetty/openclip")
                }

                // Diagnostics
                SettingsCard("Diagnostics") {
                    SettingsRow(
                        title: "Logs",
                        subtitle: "Attach these when reporting a problem."
                    ) {
                        HStack(spacing: 10) {
                            Button(isExporting ? String(localized: "Exporting…") : String(localized: "Export…")) {
                                exportLogs()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(SettingsDesignTokens.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .settingsGlassCapsule()
                            .contentShape(Capsule())
                            .disabled(isExporting)

                            Button(String(localized: "Reveal")) {
                                LogExporter.showLogsInFinder()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(SettingsDesignTokens.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .settingsGlassCapsule()
                            .contentShape(Capsule())
                        }
                    }
                }

                Text("以 AGPL-3.0 授權條款開放原始碼 · 基於 OpenClip © Ganesh M and OpenClip Contributors")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Pieces

    private var identityBlock: some View {
        VStack(spacing: 6) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .frame(width: 72, height: 72)

            Text("Qutran")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(SettingsDesignTokens.primaryText)

            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("離線翻譯 · 揀字即用")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var updateActionTitle: String {
        updateManager.availableUpdateVersion == nil
            ? String(localized: "Check Now")
            : String(localized: "View Update…")
    }

    private var updateStatusSubtitle: LocalizedStringKey? {
        guard updateManager.updatesEnabled else {
            return "Updates are disabled in development builds."
        }
        if let newVersion = updateManager.availableUpdateVersion {
            return LocalizedStringKey("Version \(newVersion)")
        }
        guard let lastCheck = updateManager.lastUpdateCheckDate else {
            return nil
        }
        return LocalizedStringKey("Last checked: \(Self.shortTimeAgo(lastCheck))")
    }

    private func linkRow(_ title: LocalizedStringKey, systemImage: String, url: String) -> some View {
        Button {
            openURL(url)
        } label: {
            SettingsRow(title: title, systemImage: systemImage) {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func shortTimeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return String(localized: "just now") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "\(minutes)m ago") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "\(hours)h ago") }
        let days = hours / 24
        if days == 1 { return String(localized: "yesterday") }
        if days < 7 { return String(localized: "\(days)d ago") }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func exportLogs() {
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let tempZipURL = try await LogExporter.exportLogs()
                defer {
                    try? FileManager.default.removeItem(at: tempZipURL)
                }

                let panel = NSSavePanel()
                panel.title = String(localized: "Export Logs")
                panel.nameFieldStringValue = tempZipURL.lastPathComponent
                panel.allowedContentTypes = [.zip]
                panel.canCreateDirectories = true

                if panel.runModal() == .OK, let destinationURL = panel.url {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: tempZipURL, to: destinationURL)
                }
            } catch {
                SettingsRouter.shared.notifyError(
                    title: String(localized: "Export Logs Failed"),
                    message: error.localizedDescription
                )
            }
        }
    }
}

