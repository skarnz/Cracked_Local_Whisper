import Foundation
import Carbon
import AppKit
import KeyboardShortcuts

// Define keyboard shortcut name
extension KeyboardShortcuts.Name {
    static let pushToTalk = Self("pushToTalk")
}

/// Service for managing global hotkeys with custom binding support
@MainActor
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    // MARK: - Published Properties
    @Published var isHotkeyPressed = false
    @Published var currentShortcut: String = "⌘`"

    // MARK: - Private Properties
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var flagsMonitor: Any?

    // Current configured shortcut (read from KeyboardShortcuts)
    private var configuredKeyCode: UInt16 = 50 // Default: Backtick
    private var configuredModifiers: NSEvent.ModifierFlags = .command

    // MARK: - Initialization
    private init() {
        // Set default shortcut if not already set
        if KeyboardShortcuts.getShortcut(for: .pushToTalk) == nil {
            KeyboardShortcuts.setShortcut(.init(.backtick, modifiers: .command), for: .pushToTalk)
        }
        loadConfiguredShortcut()

        // Listen for shortcut changes
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            // This won't work for hold-to-record, but we use it to detect changes
        }
    }

    // MARK: - Load Configured Shortcut

    /// Load the user's configured shortcut
    func loadConfiguredShortcut() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .pushToTalk) {
            configuredKeyCode = UInt16(shortcut.key?.rawValue ?? 50)
            // KeyboardShortcuts.Shortcut.modifiers is already NSEvent.ModifierFlags
            configuredModifiers = shortcut.modifiers
            currentShortcut = shortcut.description
        } else {
            configuredKeyCode = 50
            configuredModifiers = .command
            currentShortcut = "⌘`"
        }
    }

    // MARK: - Hotkey Registration

    /// Register global hotkey listener
    func registerHotkey() {
        // Reload in case user changed it
        loadConfiguredShortcut()
        setupEventMonitors()
    }

    /// Unregister hotkey
    func unregisterHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    /// Re-register with new shortcut (call after user changes binding)
    func updateHotkey() {
        unregisterHotkey()
        registerHotkey()
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
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
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
        // Check if this matches our configured hotkey
        guard event.keyCode == configuredKeyCode,
              matchesModifiers(event.modifierFlags) else {
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
        if isHotkeyPressed && !matchesModifiers(event.modifierFlags) {
            isHotkeyPressed = false
            NotificationCenter.default.post(name: .hotkeyReleased, object: nil)
        }
    }

    /// Check if event modifiers match configured modifiers
    private func matchesModifiers(_ eventModifiers: NSEvent.ModifierFlags) -> Bool {
        // Check required modifiers are present
        let required = configuredModifiers.intersection([.command, .option, .control, .shift])
        let actual = eventModifiers.intersection([.command, .option, .control, .shift])
        return actual.contains(required)
    }

    // MARK: - Shortcut Configuration

    /// Update the displayed shortcut string
    func updateCurrentShortcutDisplay() {
        loadConfiguredShortcut()
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

