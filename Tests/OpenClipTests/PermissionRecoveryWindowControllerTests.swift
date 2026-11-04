// PermissionRecoveryWindowControllerTests.swift
// OpenClipTests
//
// Tests for PermissionRecoveryWindowController verifying dismissal delegation and callback idempotency.
import XCTest
import AppKit
@testable import OpenClip

@MainActor
final class PermissionRecoveryWindowControllerTests: XCTestCase {

    func testAlreadyGrantedPermissionClosesRecoveryWindowOnFirstPresentation() async {
        let manager = PermissionManager(
            accessibilityQuery: { true }, screenRecordingQuery: { true },
            requestScreenCapture: { false }, openSettings: { _ in }, notificationCenter: NotificationCenter()
        )
        defer { manager.stopMonitoring() }
        let completed = expectation(description: "Already granted window dismisses")
        var completions = 0
        let controller = PermissionRecoveryWindowController(
            isUpdate: false, permissionManager: manager,
            onComplete: { completions += 1; completed.fulfill() }
        )
        controller.showWindow(nil)
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(completions, 1)
        XCTAssertFalse(controller.window?.isVisible ?? false)
        controller.close()
    }

    func testHandleCompleteInvokesCallbackOnceAndClosesWindow() {
        var completeCount = 0
        var dismissCount = 0

        let controller = PermissionRecoveryWindowController(
            isUpdate: true,
            onComplete: { completeCount += 1 },
            onDismiss: { dismissCount += 1 }
        )

        controller.handleComplete()
        // Second attempt to ensure idempotency
        controller.handleComplete()
        controller.handleDismiss()

        XCTAssertEqual(completeCount, 1)
        XCTAssertEqual(dismissCount, 0)
    }

    func testWindowWillCloseInvokesOnDismissOnlyOnce() {
        var completeCount = 0
        var dismissCount = 0

        let controller = PermissionRecoveryWindowController(
            isUpdate: false,
            onComplete: { completeCount += 1 },
            onDismiss: { dismissCount += 1 }
        )

        guard let window = controller.window else {
            XCTFail("Missing window")
            return
        }

        // Simulate title-bar close button notification
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))

        XCTAssertEqual(completeCount, 0)
        XCTAssertEqual(dismissCount, 1)
    }
}

@MainActor
final class PermissionManagerTests: XCTestCase {
    func testTestHostHasSeparateIdentityFromInstalledApp() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.qutran.Qutran.TestHost")
        XCTAssertEqual(Bundle.main.bundleURL.lastPathComponent, "Qutran Test Host.app")
    }

    func testOpeningAlreadyGrantedScreenPermissionDoesNotRequestAgain() {
        var requests = 0
        var opened: [URL] = []
        let manager = PermissionManager(
            accessibilityQuery: { true }, screenRecordingQuery: { true },
            requestScreenCapture: { requests += 1; return true },
            openSettings: { opened.append($0) }, notificationCenter: NotificationCenter()
        )
        defer { manager.stopMonitoring() }
        manager.requestScreenRecordingPermission()
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(manager.isScreenRecordingGranted)
        XCTAssertEqual(opened.first?.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    func testScreenPermissionRequestRefreshesFromActualSystemState() {
        var granted = false
        var requests = 0
        let manager = PermissionManager(
            accessibilityQuery: { false }, screenRecordingQuery: { granted },
            requestScreenCapture: { requests += 1; granted = true; return true },
            openSettings: { _ in }, notificationCenter: NotificationCenter()
        )
        defer { manager.stopMonitoring() }
        manager.requestScreenRecordingPermission()
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(manager.isScreenRecordingGranted)
        manager.requestScreenRecordingPermission()
        XCTAssertEqual(requests, 1)
    }

    func testReturningFromSystemSettingsRefreshesBothPermissionsWithoutPolling() async {
        var granted = false
        let center = NotificationCenter()
        let refreshed = expectation(description: "Refresh after activation")
        let manager = PermissionManager(
            accessibilityQuery: { granted },
            screenRecordingQuery: {
                if granted { refreshed.fulfill() }
                return granted
            },
            requestScreenCapture: { false }, openSettings: { _ in }, notificationCenter: center
        )
        manager.stopMonitoring()
        granted = true
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertTrue(manager.isAccessibilityGranted)
        XCTAssertTrue(manager.isScreenRecordingGranted)
    }

    func testStartingMonitoringImmediatelyRefreshesStatus() {
        var granted = false
        let manager = PermissionManager(
            accessibilityQuery: { granted }, screenRecordingQuery: { granted },
            requestScreenCapture: { false }, openSettings: { _ in }, notificationCenter: NotificationCenter()
        )
        defer { manager.stopMonitoring() }
        granted = true
        manager.startMonitoring()
        XCTAssertTrue(manager.isAccessibilityGranted)
        XCTAssertTrue(manager.isScreenRecordingGranted)
        granted = false
        manager.startMonitoring()
        XCTAssertFalse(manager.isAccessibilityGranted)
        XCTAssertFalse(manager.isScreenRecordingGranted)
    }
}
