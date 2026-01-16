import Foundation
import AVFoundation
import AppKit

/// Manages system permissions for microphone and accessibility
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false

    private init() {
        checkPermissions()
    }

    // MARK: - Permission Checking

    /// Check all permissions
    func checkPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    /// Check microphone permission status
    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        case .notDetermined, .denied, .restricted:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
    }

    /// Check accessibility permission status
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    // MARK: - Permission Requests

    /// Request microphone access
    func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasMicrophonePermission = granted
            }
        }
    }

    /// Request accessibility access (opens System Preferences)
    func requestAccessibilityAccess() {
        // Check if already trusted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Open System Preferences to Accessibility pane
            openAccessibilityPreferences()
        }

        hasAccessibilityPermission = trusted
    }

    /// Open System Preferences to Accessibility pane
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Open System Preferences to Microphone pane
    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Permission Alerts

    /// Show alert for missing microphone permission
    func showMicrophonePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "Cracked Local Whisper needs microphone access to transcribe your voice. Please grant permission in System Preferences."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Preferences")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openMicrophonePreferences()
        }
    }

    /// Show alert for missing accessibility permission
    func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Cracked Local Whisper needs accessibility access to paste transcribed text. Please grant permission in System Preferences."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Preferences")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
}
