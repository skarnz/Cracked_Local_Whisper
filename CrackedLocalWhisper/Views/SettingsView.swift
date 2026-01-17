import SwiftUI
import KeyboardShortcuts

/// Settings/Preferences window view
struct SettingsView: View {
    @EnvironmentObject var whisperService: WhisperService

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsTab()
                .environmentObject(whisperService)
                .tabItem {
                    Label("Models", systemImage: "cube.box")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }

            UpdatesSettingsTab()
                .tabItem {
                    Label("Updates", systemImage: "arrow.clockwise")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 350)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("playSound") private var playSound = true
    @AppStorage("restoreClipboard") private var restoreClipboard = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Show in Dock", isOn: $showInDock)
            }

            Section("Behavior") {
                Toggle("Play Sound on Transcription", isOn: $playSound)
                Toggle("Restore Clipboard After Paste", isOn: $restoreClipboard)
                    .help("Restores previous clipboard content after pasting transcription")
            }

            Section("Permissions") {
                PermissionsStatusView()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Model Settings Tab
struct ModelSettingsTab: View {
    @EnvironmentObject var whisperService: WhisperService
    @State private var isRefreshing = false

    var body: some View {
        Form {
            Section("Current Model") {
                Picker("Model", selection: $whisperService.selectedModel) {
                    ForEach(WhisperModelVariant.allCases) { model in
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            Text(model.estimatedSize)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }

                if whisperService.isLoading {
                    HStack {
                        ProgressView(value: whisperService.loadingProgress)
                        Text(whisperService.loadingMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Downloaded Models") {
                if whisperService.downloadedModels.isEmpty {
                    Text("No models downloaded yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(whisperService.downloadedModels).sorted(), id: \.self) { model in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(model)
                            Spacer()
                            Button("Delete") {
                                deleteModel(model)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }

            Section {
                Button("Refresh Model List") {
                    Task {
                        isRefreshing = true
                        await whisperService.fetchAvailableModels()
                        isRefreshing = false
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func deleteModel(_ model: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelPath = appSupport.appendingPathComponent("CrackedLocalWhisper/Models/\(model)")
        try? FileManager.default.removeItem(at: modelPath)
        whisperService.scanDownloadedModels()
    }
}

// MARK: - Shortcuts Settings Tab
struct ShortcutsSettingsTab: View {
    @State private var currentShortcut: String = HotkeyService.shared.currentShortcut

    var body: some View {
        Form {
            Section("Push-to-Talk") {
                KeyboardShortcuts.Recorder("Hotkey", name: .pushToTalk)
                    .padding(.vertical, 4)
                    .onChange(of: KeyboardShortcuts.getShortcut(for: .pushToTalk)) { _, _ in
                        // Update hotkey when user changes it
                        Task { @MainActor in
                            HotkeyService.shared.updateHotkey()
                            currentShortcut = HotkeyService.shared.currentShortcut
                        }
                    }

                Text("Hold to record, release to transcribe and paste")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Current Binding") {
                HStack {
                    Text("Active Shortcut")
                    Spacer()
                    Text(currentShortcut)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            }

            Section {
                Button("Reset to Default (⌘`)") {
                    KeyboardShortcuts.reset(.pushToTalk)
                    Task { @MainActor in
                        HotkeyService.shared.updateHotkey()
                        currentShortcut = HotkeyService.shared.currentShortcut
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Updates Settings Tab
struct UpdatesSettingsTab: View {
    @StateObject private var updateService = ModelUpdateService.shared
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    var body: some View {
        Form {
            Section("Automatic Updates") {
                Toggle("Check for Model Updates Daily", isOn: $autoCheckUpdates)
                    .onChange(of: autoCheckUpdates) { _, newValue in
                        Task {
                            if newValue {
                                try? updateService.installLaunchAgent()
                            } else {
                                try? updateService.uninstallLaunchAgent()
                            }
                        }
                    }

                if let lastCheck = updateService.lastCheckDate {
                    HStack {
                        Text("Last checked:")
                        Spacer()
                        Text(lastCheck, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(updateService.updateStatus)
                    .font(.caption)
                    .foregroundStyle(updateService.updateAvailable ? .orange : .secondary)
            }

            Section {
                Button("Check Now") {
                    Task {
                        await updateService.checkForUpdates()
                    }
                }
                .disabled(updateService.isCheckingForUpdates)

                if updateService.isCheckingForUpdates {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Section("Background Service") {
                HStack {
                    Text("LaunchAgent Status")
                    Spacer()
                    Text(updateService.isLaunchAgentInstalled ? "Installed" : "Not Installed")
                        .foregroundStyle(updateService.isLaunchAgentInstalled ? .green : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Cracked Local Whisper")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .foregroundStyle(.secondary)

            Text("100% local speech-to-text powered by WhisperKit")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/skarnz/Cracked_Local_Whisper")!)
                Link("WhisperKit", destination: URL(string: "https://github.com/argmaxinc/WhisperKit")!)
            }

            Text("Built with ❤️ using WhisperKit by Argmax")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

// MARK: - Permissions Status View
struct PermissionsStatusView: View {
    @State private var hasMicPermission = false
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PermissionRow(
                title: "Microphone",
                hasPermission: hasMicPermission,
                action: {
                    PermissionsManager.shared.requestMicrophoneAccess()
                }
            )

            PermissionRow(
                title: "Accessibility",
                hasPermission: hasAccessibilityPermission,
                action: {
                    PermissionsManager.shared.requestAccessibilityAccess()
                }
            )
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        hasMicPermission = PermissionsManager.shared.hasMicrophonePermission
        hasAccessibilityPermission = PermissionsManager.shared.hasAccessibilityPermission
    }
}

struct PermissionRow: View {
    let title: String
    let hasPermission: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(hasPermission ? .green : .red)

            Text(title)

            Spacer()

            if !hasPermission {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(WhisperService.shared)
}
