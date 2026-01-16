import Foundation

/// Represents the result of a transcription
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval
    let model: String
    let language: String?
    let segments: [TranscriptionSegment]?

    init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        model: String = "base",
        language: String? = nil,
        segments: [TranscriptionSegment]? = nil
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.model = model
        self.language = language
        self.segments = segments
    }
}

/// Represents a segment of transcription with timing
struct TranscriptionSegment: Identifiable, Codable {
    let id: Int
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    let probability: Float?
}

/// History of transcriptions
class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()

    @Published var items: [TranscriptionResult] = []

    private let maxItems = 100
    private let storageKey = "transcriptionHistory"

    private init() {
        loadHistory()
    }

    func add(_ result: TranscriptionResult) {
        items.insert(result, at: 0)

        // Keep only maxItems
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        saveHistory()
    }

    func clear() {
        items.removeAll()
        saveHistory()
    }

    func delete(_ result: TranscriptionResult) {
        items.removeAll { $0.id == result.id }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TranscriptionResult].self, from: data) else {
            return
        }
        items = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
