import Foundation
import WhisperKit
import Combine

/// Available Whisper model variants
enum WhisperModelVariant: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case tinyEn = "tiny.en"
    case base = "base"
    case baseEn = "base.en"
    case small = "small"
    case smallEn = "small.en"
    case medium = "medium"
    case mediumEn = "medium.en"
    case largeV3 = "large-v3"
    case distilLargeV3 = "distil-large-v3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (Fastest)"
        case .tinyEn: return "Tiny English"
        case .base: return "Base (Recommended)"
        case .baseEn: return "Base English"
        case .small: return "Small"
        case .smallEn: return "Small English"
        case .medium: return "Medium"
        case .mediumEn: return "Medium English"
        case .largeV3: return "Large V3 (Best)"
        case .distilLargeV3: return "Distil Large V3"
        }
    }

    var estimatedSize: String {
        switch self {
        case .tiny, .tinyEn: return "~75MB"
        case .base, .baseEn: return "~150MB"
        case .small, .smallEn: return "~500MB"
        case .medium, .mediumEn: return "~1.5GB"
        case .largeV3: return "~3GB"
        case .distilLargeV3: return "~1.5GB"
        }
    }
}

/// WhisperKit service for local speech-to-text transcription
@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isTranscribing = false
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage = ""
    @Published var lastTranscription: String?
    @Published var error: String?
    @Published var selectedModel: WhisperModelVariant {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
            Task { await loadModel() }
        }
    }
    @Published var availableModels: [WhisperModelVariant] = []
    @Published var downloadedModels: Set<String> = []

    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private let modelDirectory: URL

    // MARK: - Initialization
    private init() {
        // Load saved model preference
        let savedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base"
        self.selectedModel = WhisperModelVariant(rawValue: savedModel) ?? .base

        // Setup model directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelDirectory = appSupport.appendingPathComponent("CrackedLocalWhisper/Models", isDirectory: true)

        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        // Scan for downloaded models
        scanDownloadedModels()

        // Load model on init
        Task {
            await loadModel()
        }
    }

    // MARK: - Model Management

    /// Scan local directory for downloaded models
    func scanDownloadedModels() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)
            downloadedModels = Set(contents.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent })
        } catch {
            downloadedModels = []
        }
    }

    /// Load the selected model, downloading if necessary
    func loadModel() async {
        guard !isLoading else { return }

        isLoading = true
        loadingProgress = 0
        loadingMessage = "Initializing \(selectedModel.displayName)..."
        error = nil

        do {
            let config = WhisperKitConfig(
                model: selectedModel.rawValue,
                downloadBase: modelDirectory.path,
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: false,
                prewarm: true
            )

            loadingMessage = "Downloading model (if needed)..."

            whisperKit = try await WhisperKit(config) { progress in
                Task { @MainActor in
                    self.loadingProgress = progress.fractionCompleted
                    self.loadingMessage = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                }
            }

            loadingMessage = "Model ready!"
            scanDownloadedModels()

        } catch {
            self.error = "Failed to load model: \(error.localizedDescription)"
            print("WhisperKit error: \(error)")
        }

        isLoading = false
    }

    /// Fetch available models from remote
    func fetchAvailableModels() async {
        do {
            if let models = try await WhisperKit.recommendedRemoteModels() {
                let variants = models.compactMap { WhisperModelVariant(rawValue: $0) }
                availableModels = variants.isEmpty ? WhisperModelVariant.allCases : variants
            }
        } catch {
            availableModels = WhisperModelVariant.allCases
        }
    }

    // MARK: - Transcription

    /// Transcribe audio from file path
    func transcribe(audioPath: URL) async -> String? {
        guard let whisperKit = whisperKit else {
            error = "Model not loaded"
            return nil
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let result = try await whisperKit.transcribe(audioPath: audioPath.path)
            let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            lastTranscription = text
            return text
        } catch {
            self.error = "Transcription failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Transcribe from current recording buffer
    func transcribeRecording() async {
        let audioService = AudioCaptureService.shared
        guard let audioURL = audioService.recordingURL else {
            error = "No recording available"
            return
        }

        _ = await transcribe(audioPath: audioURL)
    }

    /// Transcribe audio samples directly (for streaming)
    func transcribe(samples: [Float]) async -> String? {
        guard let whisperKit = whisperKit else {
            error = "Model not loaded"
            return nil
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let result = try await whisperKit.transcribe(audioArray: samples)
            let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            lastTranscription = text
            return text
        } catch {
            self.error = "Transcription failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Model Info

    /// Check if current model is downloaded
    var isModelDownloaded: Bool {
        downloadedModels.contains(selectedModel.rawValue) || whisperKit != nil
    }

    /// Get model version info
    func getModelVersion() -> String? {
        // WhisperKit doesn't expose version directly, use file modification date
        let modelPath = modelDirectory.appendingPathComponent(selectedModel.rawValue)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: modDate)
    }
}
