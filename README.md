# Cracked Local Whisper

**100% local speech-to-text for macOS** powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit).

Push-to-talk dictation with a floating voice bar, waveform visualization, and automatic transcription pasting.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Native-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **🎙️ Push-to-Talk** - Hold `Cmd+`` to record, release to transcribe
- **🌊 Floating Voice Bar** - Sleek waveform visualization during recording
- **📋 Auto-Paste** - Transcription automatically pastes to active text field
- **🔒 100% Local** - All processing on-device via CoreML, no data leaves your Mac
- **📦 Model Selector** - Choose from tiny to large-v3 models
- **🔄 Auto-Updates** - Checks for latest SOTA models daily via LaunchAgent
- **⚡ Apple Silicon** - Native performance on M1/M2/M3 chips

## Installation

### From DMG (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/skarnz/Cracked_Local_Whisper/releases)
2. Open the DMG and drag the app to Applications
3. Open the app and grant required permissions:
   - **Microphone** - For voice recording
   - **Accessibility** - For auto-paste feature

### From Source

```bash
# Clone the repository
git clone https://github.com/skarnz/Cracked_Local_Whisper.git
cd Cracked_Local_Whisper

# Install XcodeGen (if not installed)
brew install xcodegen

# Generate Xcode project
cd CrackedLocalWhisper
xcodegen generate

# Open in Xcode
open CrackedLocalWhisper.xcodeproj
```

## Usage

### Basic Usage

1. **Start Recording**: Hold `Cmd+`` (backtick)
2. **Speak**: The floating voice bar shows your audio waveform
3. **Release**: Transcription happens instantly
4. **Auto-Paste**: Text is automatically pasted to the active text field

### Changing Models

Click the menu bar icon → Select a model from the dropdown:

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| Tiny | ~75MB | Fastest | Basic |
| Base | ~150MB | Fast | Good |
| Small | ~500MB | Medium | Better |
| Medium | ~1.5GB | Slow | High |
| Large-v3 | ~3GB | Slowest | Best |
| Distil-Large-v3 | ~1.5GB | Fast | Near-Best |

Models are downloaded automatically on first use.

### Customizing Hotkey

1. Open **Settings** from the menu bar
2. Go to **Shortcuts** tab
3. Click the recorder and press your desired key combination

## Auto-Update System

Cracked Local Whisper includes an automatic model update system:

- **Daily Check**: A LaunchAgent runs at 3 AM to check for new models
- **HuggingFace Integration**: Monitors [argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml)
- **Optional**: Enable/disable in Settings → Updates

### Manual Update Check

```bash
# Check for updates
swift ~/.local/share/CrackedLocalWhisper/update_models.swift
```

## Building

### Requirements

- macOS 14.0+
- Xcode 15.0+
- Apple Silicon Mac (M1/M2/M3)

### Build Commands

```bash
# Build the app
./scripts/build.sh

# Package as DMG
./scripts/package-dmg.sh
```

### Code Signing (for distribution)

```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: YOUR_NAME" \
    "build/Cracked Local Whisper.app"

# Sign the DMG
codesign --sign "Developer ID Application: YOUR_NAME" \
    "build/CrackedLocalWhisper-1.0.0.dmg"

# Notarize
xcrun notarytool submit "build/CrackedLocalWhisper-1.0.0.dmg" \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password YOUR_APP_PASSWORD \
    --wait
```

## Project Structure

```
CrackedLocalWhisper/
├── App/
│   └── CrackedLocalWhisperApp.swift    # App entry point
├── Views/
│   ├── FloatingVoiceBar.swift          # Main floating UI
│   ├── WaveformView.swift              # Audio visualization
│   ├── MenuBarView.swift               # Menu bar dropdown
│   ├── ModelSelectorView.swift         # Model picker
│   └── SettingsView.swift              # Preferences
├── Services/
│   ├── WhisperService.swift            # WhisperKit integration
│   ├── AudioCaptureService.swift       # Mic recording
│   ├── HotkeyService.swift             # Global hotkeys
│   ├── PasteService.swift              # Auto-paste
│   ├── ModelUpdateService.swift        # SOTA updates
│   └── PermissionsManager.swift        # Permission handling
├── Models/
│   └── TranscriptionResult.swift       # Data models
└── Resources/
    ├── Info.plist
    └── CrackedLocalWhisper.entitlements
```

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Local ML transcription
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey handling

## Credits

- **WhisperKit** by [Argmax](https://github.com/argmaxinc) - The incredible local ML transcription engine
- **OpenSuperWhisper** by [Starmel](https://github.com/Starmel/OpenSuperWhisper) - UI inspiration

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Made with ❤️ for local-first AI**
