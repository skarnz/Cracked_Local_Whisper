import SwiftUI
import KeyboardShortcuts

@main
struct CrackedLocalWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var whisperService = WhisperService.shared
    @StateObject private var audioService = AudioCaptureService.shared
    @StateObject private var hotkeyService = HotkeyService.shared

    var body: some Scene {
        // Menu bar app with settings window
        MenuBarExtra {
            MenuBarView()
                .environmentObject(whisperService)
                .environmentObject(audioService)
        } label: {
            Image(systemName: whisperService.isTranscribing ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(whisperService)
        }
    }
}

// MARK: - App Delegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request necessary permissions
        PermissionsManager.shared.requestMicrophoneAccess()
        PermissionsManager.shared.requestAccessibilityAccess()

        // Setup floating voice bar window
        setupFloatingWindow()

        // Register global hotkey
        HotkeyService.shared.registerHotkey()

        // Check for model updates on launch
        Task {
            await ModelUpdateService.shared.checkForUpdates()
        }

        // Hide dock icon (menu bar app)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.unregisterHotkey()
    }

    private func setupFloatingWindow() {
        let contentView = FloatingVoiceBar()
            .environmentObject(WhisperService.shared)
            .environmentObject(AudioCaptureService.shared)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = panel.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - windowFrame.height - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        floatingWindow = panel

        // Bind visibility to hotkey state
        NotificationCenter.default.addObserver(
            forName: .hotkeyPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showFloatingWindow()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .hotkeyReleased,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideFloatingWindow()
            }
        }
    }

    func showFloatingWindow() {
        floatingWindow?.orderFront(nil)
        floatingWindow?.makeKey()
        AudioCaptureService.shared.startRecording()
    }

    func hideFloatingWindow() {
        AudioCaptureService.shared.stopRecording()

        // Transcribe and paste
        Task {
            await WhisperService.shared.transcribeRecording()
            if let text = WhisperService.shared.lastTranscription, !text.isEmpty {
                PasteService.shared.pasteText(text)
            }
            floatingWindow?.orderOut(nil)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let hotkeyPressed = Notification.Name("hotkeyPressed")
    static let hotkeyReleased = Notification.Name("hotkeyReleased")
}
