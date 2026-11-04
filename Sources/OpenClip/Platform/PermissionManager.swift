// PermissionManager.swift
// OpenClip
//
// Checks and prompts for required macOS Accessibility permissions necessary for text retrieval and event monitoring.
import AppKit
import Combine
import ApplicationServices
import Core

/// Polls `AXIsProcessTrusted` with an async loop on the main actor rather than a Timer.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var isAccessibilityGranted: Bool = false
    /// Screen Recording, needed only by Capture Text. Optional: the rest of the app works without it.
    @Published public private(set) var isScreenRecordingGranted: Bool = false

    private var pollingTask: Task<Void, Never>?
    private var didLogStatus = false

    private let accessibilityQuery: @MainActor () -> Bool
    private let screenRecordingQuery: @MainActor () -> Bool
    private let requestScreenCapture: @MainActor () -> Bool
    private let openSettings: @MainActor (URL) -> Void
    private let notificationCenter: NotificationCenter
    private var activationSubscription: AnyCancellable?

    init(
        accessibilityQuery: @escaping @MainActor () -> Bool = PermissionManager.queryAX,
        screenRecordingQuery: @escaping @MainActor () -> Bool = PermissionManager.queryScreenRecording,
        requestScreenCapture: @escaping @MainActor () -> Bool = { CGRequestScreenCaptureAccess() },
        openSettings: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) },
        notificationCenter: NotificationCenter = .default
    ) {
        self.accessibilityQuery = accessibilityQuery
        self.screenRecordingQuery = screenRecordingQuery
        self.requestScreenCapture = requestScreenCapture
        self.openSettings = openSettings
        self.notificationCenter = notificationCenter
        self.isAccessibilityGranted = accessibilityQuery()
        self.isScreenRecordingGranted = screenRecordingQuery()
        activationSubscription = notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.checkStatus() }
            }
    }

    // MARK: - Public API

    public func startMonitoring() {
        checkStatus()
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.checkStatus()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
            }
        }
    }

    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func checkStatus() {
        let current = accessibilityQuery()
        let screenRecording = screenRecordingQuery()
        if !didLogStatus || current != isAccessibilityGranted || screenRecording != isScreenRecordingGranted {
            Log.permissions.info("permission status accessibility=\(current, privacy: .public) screenRecording=\(screenRecording, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public) app=\(Bundle.main.bundleURL.path, privacy: .public)")
            didLogStatus = true
        }
        if isAccessibilityGranted != current {
            isAccessibilityGranted = current
            notificationCenter.post(name: .openClipAccessibilityChanged, object: current)
        }
        if isScreenRecordingGranted != screenRecording {
            isScreenRecordingGranted = screenRecording
        }
    }

    /// Requests access for the running app without removing an existing TCC grant.
    public func requestScreenRecordingPermission() {
        startMonitoring()
        if !screenRecordingQuery() {
            _ = requestScreenCapture()
            checkStatus()
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            openSettings(url)
        }
    }

    /// Prompts TCC to evaluate the running binary. TCC entries are reset only by `resetTCCAndRelaunch`.
    public func requestAccessibilityPermission() {
        startMonitoring()
        promptAndOpenAccessibilitySettings()
    }

    private func promptAndOpenAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reset TCC permission database entry for OpenClip if macOS TCC is caching a stale signature.
    public func resetTCCAndRelaunch() {
        // Async: never `waitUntilExit` on the main actor. The app relaunches regardless.
        Task {
            do {
                _ = try await ShellProcessRunner.run(ShellProcessRunner.Invocation(
                    executableURL: URL(fileURLWithPath: "/usr/bin/tccutil"),
                    arguments: ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.openclip.OpenClip"],
                    environment: [:]
                ))
            } catch {
                Log.permissions.error("Failed to run tccutil reset for Accessibility permission: \(error.localizedDescription)")
            }
            relaunchApp()
        }
    }

    /// Relaunch the app so macOS TCC registers the new permission for the running process.
    public func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            guard let app else {
                Log.permissions.error("Unable to relaunch app: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            let launchedPID = app.processIdentifier
            DispatchQueue.main.async {
                guard launchedPID != ProcessInfo.processInfo.processIdentifier else { return }
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Internal

    /// Queries trust for this running process and its code identity.
    private static func queryAX() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    private static func queryScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
