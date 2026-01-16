import Foundation
import Carbon
import AppKit
import KeyboardShortcuts

// Define keyboard shortcut name
extension KeyboardShortcuts.Name {
    static let pushToTalk = Self("pushToTalk")
}

/// Service for managing global hotkeys (Cmd+` default)
@MainActor
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    // MARK: - Published Properties
    @Published var isHotkeyPressed = false
    @Published var currentShortcut: String = "⌘`"

    // MARK: - Private Properties
    private var eventMonitor: Any?
    private var flagsMonitor: Any?

    // Default hotkey: Cmd + Backtick (`)
    private let defaultKeyCode: UInt16 = 50 // Backtick key
    private let defaultModifiers: NSEvent.ModifierFlags = .command

    // MARK: - Initialization
    private init() {
        // Set default shortcut if not already set
        if KeyboardShortcuts.getShortcut(for: .pushToTalk) == nil {
            KeyboardShortcuts.setShortcut(.init(.backtick, modifiers: .command), for: .pushToTalk)
        }
        updateCurrentShortcutDisplay()
    }

    // MARK: - Hotkey Registration

    /// Register global hotkey listener
    func registerHotkey() {
        // Use low-level event monitoring for push-to-talk (hold to record)
        setupEventMonitors()
    }

    /// Unregister hotkey
    func unregisterHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    // MARK: - Event Monitoring

    private func setupEventMonitors() {
        // Monitor key events globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        // Also monitor local events (when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
            return event
        }

        // Monitor modifier flags changes
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for our hotkey (Cmd + `)
        guard event.keyCode == defaultKeyCode,
              event.modifierFlags.contains(defaultModifiers) else {
            return
        }

        if event.type == .keyDown && !isHotkeyPressed {
            isHotkeyPressed = true
            NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
        } else if event.type == .keyUp && isHotkeyPressed {
            isHotkeyPressed = false
            NotificationCenter.default.post(name: .hotkeyReleased, object: nil)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Release hotkey if modifier is released while key is held
        if isHotkeyPressed && !event.modifierFlags.contains(defaultModifiers) {
            isHotkeyPressed = false
            NotificationCenter.default.post(name: .hotkeyReleased, object: nil)
        }
    }

    // MARK: - Shortcut Configuration

    /// Update the displayed shortcut string
    func updateCurrentShortcutDisplay() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .pushToTalk) {
            currentShortcut = shortcut.description
        } else {
            currentShortcut = "⌘`"
        }
    }

    /// Check if accessibility permissions are granted
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Open accessibility settings
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Custom Key Extension for Backtick
extension KeyboardShortcuts.Key {
    static let backtick = Self(rawValue: 50) // Backtick key code
}
