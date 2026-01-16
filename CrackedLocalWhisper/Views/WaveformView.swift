import SwiftUI

/// Real-time waveform visualization of audio input
struct WaveformView: View {
    let samples: [Float]
    let isActive: Bool

    // Configuration
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 1.5

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    WaveformBar(
                        amplitude: CGFloat(sample),
                        isActive: isActive,
                        index: index,
                        totalBars: samples.count
                    )
                    .frame(width: barWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Individual Waveform Bar
struct WaveformBar: View {
    let amplitude: CGFloat
    let isActive: Bool
    let index: Int
    let totalBars: Int

    @State private var animatedAmplitude: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let maxHeight = geometry.size.height
            let barHeight = max(4, animatedAmplitude * maxHeight * 2)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(barGradient)
                .frame(width: 3, height: barHeight)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .onChange(of: amplitude) { _, newValue in
            withAnimation(.easeOut(duration: 0.1)) {
                animatedAmplitude = newValue
            }
        }
        .onAppear {
            animatedAmplitude = amplitude
        }
    }

    private var barGradient: LinearGradient {
        if isActive {
            // Active recording - gradient from green to red based on amplitude
            let intensity = min(1, amplitude * 2)
            return LinearGradient(
                colors: [
                    Color(hue: 0.3 - Double(intensity) * 0.3, saturation: 0.8, brightness: 0.9),
                    Color(hue: 0.3 - Double(intensity) * 0.3, saturation: 0.6, brightness: 0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Inactive - gray bars
            return LinearGradient(
                colors: [.gray.opacity(0.4), .gray.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Animated Waveform (for idle state)
struct IdleWaveform: View {
    @State private var phase: CGFloat = 0
    let barCount: Int = 30

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let amplitude = sin(phase + CGFloat(index) * 0.3) * 0.3 + 0.5
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.gray.opacity(0.3))
                    .frame(width: 3, height: max(4, amplitude * 30))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Circular Audio Level Indicator
struct AudioLevelIndicator: View {
    let level: Float
    let isRecording: Bool

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(.gray.opacity(0.2), lineWidth: 4)

            // Level arc
            Circle()
                .trim(from: 0, to: CGFloat(level))
                .stroke(
                    isRecording ? Color.red : Color.green,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.1), value: level)

            // Center mic icon
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundStyle(isRecording ? .red : .secondary)
        }
        .frame(width: 50, height: 50)
    }
}

// MARK: - Preview
#Preview("Waveform - Active") {
    let samples = (0..<50).map { _ in Float.random(in: 0...1) }
    return WaveformView(samples: samples, isActive: true)
        .frame(width: 300, height: 60)
        .padding()
        .background(Color.black.opacity(0.8))
}

#Preview("Waveform - Inactive") {
    let samples = Array(repeating: Float(0.1), count: 50)
    return WaveformView(samples: samples, isActive: false)
        .frame(width: 300, height: 60)
        .padding()
        .background(Color.black.opacity(0.8))
}

#Preview("Audio Level Indicator") {
    HStack(spacing: 20) {
        AudioLevelIndicator(level: 0.3, isRecording: false)
        AudioLevelIndicator(level: 0.7, isRecording: true)
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
