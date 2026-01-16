import Foundation
import AppKit
import Carbon

/// Service for pasting transcribed text to the active application
class PasteService {
    static let shared = PasteService()

    private init() {}

    // MARK: - Paste Methods

    /// Paste text to the currently active text field
    /// Uses clipboard + Cmd+V simulation
    func pasteText(_ text: String) {
        guard !text.isEmpty else { return }

        // Save current clipboard content
        let pasteboard = NSPasteboard.general
        let savedContents = pasteboard.string(forType: .string)

        // Set our text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Simulate Cmd+V
            self.simulatePaste()

            // Optionally restore previous clipboard content after paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let saved = savedContents, UserDefaults.standard.bool(forKey: "restoreClipboard") {
                    pasteboard.clearContents()
                    pasteboard.setString(saved, forType: .string)
                }
            }
        }
    }

    /// Simulate Cmd+V keystroke using CGEvent
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'V'
        let keyCodeV: CGKeyCode = 0x09

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true) else {
            print("Failed to create key down event")
            return
        }
        keyDown.flags = .maskCommand

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false) else {
            print("Failed to create key up event")
            return
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Alternative: Direct Text Input via Accessibility

    /// Insert text directly using Accessibility API (requires trust)
    /// This is more reliable for some apps but requires accessibility permission
    func insertTextDirectly(_ text: String) {
        guard AXIsProcessTrusted() else {
            // Fall back to clipboard method
            pasteText(text)
            return
        }

        // Get the focused element of the frontmost app
        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = Optional(app.processIdentifier) else {
            pasteText(text)
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            // Fall back to clipboard method
            pasteText(text)
            return
        }

        // Try to set the value directly
        let setResult = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        if setResult != .success {
            // Fall back to clipboard method
            pasteText(text)
        }
    }

    // MARK: - Type Character by Character

    /// Type text character by character (slower but works everywhere)
    func typeText(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            let string = String(char)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                continue
            }

            var unichar = Array(string.utf16)
            keyDown.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)

            guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            // Small delay between characters
            Thread.sleep(forTimeInterval: 0.005)
        }
    }
}
