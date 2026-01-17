import Foundation
import AVFoundation
import Combine

/// Service for capturing audio from the microphone
@MainActor
class AudioCaptureService: ObservableObject {
    static let shared = AudioCaptureService()

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var audioLevel: Float = 0
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 100)
    @Published var recordingDuration: TimeInterval = 0

    // MARK: - Audio Engine
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private var levelTimer: Timer?

    // MARK: - Recording URL
    var recordingURL: URL? {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("recording.wav")
    }

    // MARK: - Audio Samples Buffer (for streaming)
    private var audioSamples: [Float] = []
    private let sampleRate: Double = 16000 // WhisperKit expects 16kHz

    // MARK: - Initialization
    private init() {
        setupAudioEngine()
    }

    // MARK: - Setup
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
    }

    // MARK: - Recording Control

    /// Start recording audio
    func startRecording() {
        guard !isRecording else { return }

        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create output file
        guard let outputURL = recordingURL else { return }

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Setup recording format (16kHz mono for WhisperKit)
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }

        // Create converter if sample rates differ
        let converter: AVAudioConverter?
        if inputFormat.sampleRate != sampleRate {
            converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
        } else {
            converter = nil
        }

        do {
            audioFile = try AVAudioFile(
                forWriting: outputURL,
                settings: recordingFormat.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            print("Failed to create audio file: \(error)")
            return
        }

        // Clear samples buffer
        audioSamples.removeAll()

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }

            Task { @MainActor in
                self.processAudioBuffer(buffer, converter: converter, format: recordingFormat)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
            recordingStartTime = Date()
            startLevelMonitoring()

        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    /// Stop recording and save file
    func stopRecording() {
        guard isRecording else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil

        isRecording = false
        stopLevelMonitoring()

        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Audio Processing
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter?,
        format: AVAudioFormat
    ) {
        var outputBuffer: AVAudioPCMBuffer

        if let converter = converter {
            // Convert sample rate
            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * (format.sampleRate / buffer.format.sampleRate)
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if error != nil {
                return
            }

            outputBuffer = convertedBuffer
        } else {
            outputBuffer = buffer
        }

        // Write to file
        do {
            try audioFile?.write(from: outputBuffer)
        } catch {
            print("Failed to write audio: \(error)")
        }

        // Store samples for streaming transcription
        if let channelData = outputBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
            audioSamples.append(contentsOf: samples)
        }

        // Update audio level and waveform
        updateAudioLevel(buffer: outputBuffer)
    }

    // MARK: - Level Monitoring
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS level
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))

        // Convert to decibels (0-1 range)
        let db = 20 * log10(max(rms, 0.0001))
        let normalizedLevel = max(0, min(1, (db + 60) / 60))

        audioLevel = normalizedLevel

        // Update waveform samples
        updateWaveform(samples: Array(UnsafeBufferPointer(start: channelData, count: frameLength)))
    }

    private func updateWaveform(samples: [Float]) {
        // Downsample to waveform display size
        let displayCount = waveformSamples.count
        let chunkSize = max(1, samples.count / displayCount)

        var newWaveform: [Float] = []
        for i in 0..<displayCount {
            let start = i * chunkSize
            let end = min(start + chunkSize, samples.count)
            if start < samples.count {
                let chunk = samples[start..<end]
                let maxAbs = chunk.map { abs($0) }.max() ?? 0
                newWaveform.append(maxAbs)
            } else {
                newWaveform.append(0)
            }
        }

        // Shift existing samples left and append new ones
        let samplesToKeep = max(0, waveformSamples.count - newWaveform.count)
        waveformSamples = Array(waveformSamples.suffix(samplesToKeep)) + newWaveform
    }

    // MARK: - Audio Samples Access
    func getAudioSamples() -> [Float] {
        return audioSamples
    }

    func clearAudioSamples() {
        audioSamples.removeAll()
    }
}
