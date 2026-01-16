import SwiftUI

/// Dropdown model selector view
struct ModelSelectorView: View {
    @EnvironmentObject var whisperService: WhisperService
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text("Model")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Dropdown button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    ModelIcon(variant: whisperService.selectedModel)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(whisperService.selectedModel.displayName)
                            .font(.system(size: 13, weight: .medium))

                        Text(whisperService.selectedModel.estimatedSize)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if whisperService.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Dropdown menu
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(WhisperModelVariant.allCases) { model in
                        ModelRow(
                            model: model,
                            isSelected: model == whisperService.selectedModel,
                            isDownloaded: whisperService.downloadedModels.contains(model.rawValue)
                        ) {
                            whisperService.selectedModel = model
                            withAnimation {
                                isExpanded = false
                            }
                        }

                        if model != WhisperModelVariant.allCases.last {
                            Divider()
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Model Row
struct ModelRow: View {
    let model: WhisperModelVariant
    let isSelected: Bool
    let isDownloaded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ModelIcon(variant: model)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                    Text(model.estimatedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

// MARK: - Model Icon
struct ModelIcon: View {
    let variant: WhisperModelVariant

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.gradient)
                .frame(width: 28, height: 28)

            Text(iconLetter)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var iconLetter: String {
        switch variant {
        case .tiny, .tinyEn:
            return "T"
        case .base, .baseEn:
            return "B"
        case .small, .smallEn:
            return "S"
        case .medium, .mediumEn:
            return "M"
        case .largeV3:
            return "L"
        case .distilLargeV3:
            return "D"
        }
    }

    private var iconColor: Color {
        switch variant {
        case .tiny, .tinyEn:
            return .green
        case .base, .baseEn:
            return .blue
        case .small, .smallEn:
            return .purple
        case .medium, .mediumEn:
            return .orange
        case .largeV3:
            return .red
        case .distilLargeV3:
            return .pink
        }
    }
}

// MARK: - Model Download Progress
struct ModelDownloadProgress: View {
    let progress: Double
    let modelName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloading \(modelName)")
                    .font(.caption)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#Preview {
    ModelSelectorView()
        .environmentObject(WhisperService.shared)
        .padding()
        .frame(width: 300)
}
