# Cracked Local Whisper - Development Plan

## Project Overview
Native macOS dictation app with push-to-talk, floating voice bar, and waveform visualization using WhisperKit for 100% local speech-to-text processing.

## Architecture

### Core Components
```
CrackedLocalWhisper/
├── App/
│   ├── CrackedLocalWhisperApp.swift      # App entry point, menu bar
│   └── AppDelegate.swift                  # Lifecycle, permissions
├── Views/
│   ├── FloatingVoiceBar.swift            # Main floating UI
│   ├── WaveformView.swift                # Audio visualization
│   ├── ModelSelectorView.swift           # Model picker dropdown
│   └── SettingsView.swift                # Preferences window
├── Services/
│   ├── WhisperService.swift              # WhisperKit integration
│   ├── AudioCaptureService.swift         # Mic recording
│   ├── HotkeyService.swift               # Global hotkey handling
│   ├── PasteService.swift                # Auto-paste to active app
│   └── ModelUpdateService.swift          # SOTA model auto-updater
├── Models/
│   ├── TranscriptionResult.swift         # Result data model
│   └── WhisperModel.swift                # Model metadata
└── Resources/
    └── Assets.xcassets                   # Icons, colors
```

### Key Technologies
- **SwiftUI** - Modern declarative UI
- **WhisperKit** - Local ML transcription via CoreML
- **AVFoundation** - Audio capture
- **Carbon/CGEvent** - Global hotkeys
- **Accessibility API** - Auto-paste to active field
- **LaunchAgent** - Background model updates

## Implementation Phases

### Phase 1: Core Infrastructure ✅ Complete
- [x] Project structure setup
- [x] WhisperKit SPM integration
- [x] Basic audio capture pipeline
- [x] WhisperKit transcription test

### Phase 2: UI Development ✅ Complete
- [x] Floating voice bar window (NSPanel)
- [x] Waveform visualization (real-time)
- [x] Menu bar integration
- [x] Model selector dropdown
- [x] Settings preferences

### Phase 3: Interaction Layer ✅ Complete
- [x] Global hotkey (Cmd+`) registration
- [x] Push-to-talk (hold to record)
- [x] Auto-paste via Accessibility API
- [x] Recording state management

### Phase 4: Model Management ✅ Complete
- [x] Model listing from HuggingFace
- [x] Auto-download on first use
- [x] SOTA model checker service
- [x] LaunchAgent for background updates
- [x] Model version caching

### Phase 5: Distribution ✅ Complete
- [x] Code signing configuration
- [x] DMG packaging script
- [x] Notarization workflow
- [x] README and documentation

## SOTA Model Update Strategy

### Approach: LaunchAgent + HuggingFace API
```
1. LaunchAgent runs daily check script
2. Script queries HuggingFace API for latest models
3. Compares against local model versions
4. Downloads new models if available
5. Notifies user of updates (optional)
```

### Model Version Detection
WhisperKit models follow naming: `openai_whisper-{variant}`
- Check `argmaxinc/whisperkit-coreml` repo for latest
- Parse model support config for recommendations
- Track installed versions in UserDefaults

### LaunchAgent Configuration
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.crackedlocalwhisper.modelupdater</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/swift</string>
        <string>~/.crackedlocalwhisper/update_models.swift</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

## Technical Notes

### WhisperKit Integration
```swift
import WhisperKit

// Initialize with model
let config = WhisperKitConfig(
    model: "base",
    computeOptions: .init(audioEncoderCompute: .cpuAndNeuralEngine)
)
let whisper = try await WhisperKit(config)

// Transcribe audio
let result = try await whisper.transcribe(audioPath: tempFile)
let text = result?.text ?? ""
```

### Available Models
- `tiny` / `tiny.en` - Fastest, lowest accuracy
- `base` / `base.en` - Good balance
- `small` / `small.en` - Better accuracy
- `medium` / `medium.en` - High accuracy
- `large-v3` - Best accuracy, slowest
- `distil-large-v3` - Optimized large model

### Hotkey Implementation
```swift
// Using Carbon for global hotkeys
var hotKeyRef: EventHotKeyRef?
let hotKeyID = EventHotKeyID(signature: OSType("CLWH"), id: 1)
let modifiers: UInt32 = UInt32(cmdKey)
let keyCode: UInt32 = 50 // backtick

RegisterEventHotKey(keyCode, modifiers, hotKeyID,
    GetApplicationEventTarget(), 0, &hotKeyRef)
```

### Auto-Paste Strategy
```swift
// 1. Copy transcription to clipboard
NSPasteboard.general.setString(text, forType: .string)

// 2. Simulate Cmd+V via CGEvent
let source = CGEventSource(stateID: .hidSystemState)
let keyDown = CGEvent(keyboardEventSource: source,
    virtualKey: 0x09, keyDown: true) // V key
keyDown?.flags = .maskCommand
keyDown?.post(tap: .cghidEventTap)
```

## Dependencies

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0")
]
```

## Progress Log

### 2025-01-15
- Initial project setup
- Research completed on OpenSuperWhisper and WhisperKit
- Created project structure and planning docs
- Implemented all core services:
  - WhisperService with model management
  - AudioCaptureService with waveform data
  - HotkeyService with global Cmd+` handling
  - PasteService with clipboard + CGEvent paste
  - ModelUpdateService with LaunchAgent auto-updates
  - PermissionsManager for mic/accessibility
- Built complete UI:
  - FloatingVoiceBar with animated waveform
  - WaveformView with real-time visualization
  - MenuBarView with model selector
  - SettingsView with all preferences
  - ModelSelectorView dropdown
- Created build and distribution scripts
- **Project Complete!** 🎉
