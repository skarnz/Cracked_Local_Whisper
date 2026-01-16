import SwiftUI

/// Floating voice bar UI that appears when hotkey is pressed
struct FloatingVoiceBar: View {
    @EnvironmentObject var whisperService: WhisperService
    @EnvironmentObject var audioService: AudioCaptureService

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 16) {
            // Recording indicator
            RecordingIndicator(isRecording: audioService.isRecording)

            // Waveform visualization
            WaveformView(samples: audioService.waveformSamples, isActive: audioService.isRecording)
                .frame(height: 40)

            // Status text
            StatusText(
                isRecording: audioService.isRecording,
                isTranscribing: whisperService.isTranscribing,
                duration: audioService.recordingDuration
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: audioService.isRecording ?
                                    [.red.opacity(0.6), .orange.opacity(0.4)] :
                                    [.gray.opacity(0.3), .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(width: 400)
    }
}

// MARK: - Recording Indicator
struct RecordingIndicator: View {
    let isRecording: Bool
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(isRecording ? Color.red : Color.gray.opacity(0.5))
            .frame(width: 16, height: 16)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(
                isRecording ?
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true) :
                    .default,
                value: isPulsing
            )
            .onChange(of: isRecording) { _, newValue in
                isPulsing = newValue
            }
    }
}

// MARK: - Status Text
struct StatusText: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if isRecording {
                Text(formattedDuration)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 80, alignment: .trailing)
    }

    private var statusMessage: String {
        if isTranscribing {
            return "Transcribing..."
        } else if isRecording {
            return "Recording"
        } else {
            return "Ready"
        }
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Preview
#Preview {
    FloatingVoiceBar()
        .environmentObject(WhisperService.shared)
        .environmentObject(AudioCaptureService.shared)
        .padding()
        .background(Color.black.opacity(0.8))
}
