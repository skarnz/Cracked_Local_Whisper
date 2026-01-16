import SwiftUI

/// Menu bar dropdown view
struct MenuBarView: View {
    @EnvironmentObject var whisperService: WhisperService
    @EnvironmentObject var audioService: AudioCaptureService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSection(whisperService: whisperService)

            Divider()
                .padding(.vertical, 8)

            // Model selector
            ModelSelectorSection(whisperService: whisperService)

            Divider()
                .padding(.vertical, 8)

            // Quick actions
            QuickActionsSection()

            Divider()
                .padding(.vertical, 8)

            // Footer
            FooterSection()
        }
        .padding(12)
        .frame(width: 280)
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    @ObservedObject var whisperService: WhisperService

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cracked Local Whisper")
                    .font(.headline)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Shortcut hint
            Text("⌘`")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var statusColor: Color {
        if whisperService.isLoading {
            return .yellow
        } else if whisperService.error != nil {
            return .red
        } else {
            return .green
        }
    }

    private var statusText: String {
        if whisperService.isLoading {
            return whisperService.loadingMessage
        } else if let error = whisperService.error {
            return error
        } else {
            return "Ready"
        }
    }
}

// MARK: - Model Selector Section
struct ModelSelectorSection: View {
    @ObservedObject var whisperService: WhisperService
    @State private var showAllModels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(WhisperModelVariant.allCases) { model in
                    Button {
                        whisperService.selectedModel = model
                    } label: {
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            if whisperService.downloadedModels.contains(model.rawValue) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            Text(model.estimatedSize)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(whisperService.selectedModel.displayName)
                            .font(.system(size: 13, weight: .medium))

                        Text(whisperService.selectedModel.estimatedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if whisperService.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Loading progress
            if whisperService.isLoading && whisperService.loadingProgress > 0 {
                ProgressView(value: whisperService.loadingProgress)
                    .progressViewStyle(.linear)
            }
        }
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 4) {
            MenuButton(title: "Settings...", systemImage: "gear") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            MenuButton(title: "Check for Model Updates", systemImage: "arrow.clockwise") {
                Task {
                    await ModelUpdateService.shared.checkForUpdates()
                }
            }

            MenuButton(title: "Open Models Folder", systemImage: "folder") {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let modelsFolder = appSupport.appendingPathComponent("CrackedLocalWhisper/Models")
                NSWorkspace.shared.open(modelsFolder)
            }
        }
    }
}

// MARK: - Footer Section
struct FooterSection: View {
    var body: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Link(destination: URL(string: "https://github.com/argmaxinc/WhisperKit")!) {
                Text("WhisperKit ↗")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Menu Button Component
struct MenuButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 20)

                Text(title)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environmentObject(WhisperService.shared)
        .environmentObject(AudioCaptureService.shared)
}
