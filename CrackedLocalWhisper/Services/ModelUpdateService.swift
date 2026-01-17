import Foundation

/// Service for checking and updating to latest SOTA WhisperKit models
@MainActor
class ModelUpdateService: ObservableObject {
    static let shared = ModelUpdateService()

    // MARK: - Published Properties
    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var latestModels: [String] = []
    @Published var lastCheckDate: Date?
    @Published var updateStatus: String = ""

    // MARK: - Configuration
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    private let huggingFaceAPIBase = "https://huggingface.co/api/models"
    private let checkInterval: TimeInterval = 86400 // 24 hours

    // MARK: - UserDefaults Keys
    private let lastCheckKey = "lastModelCheckDate"
    private let installedVersionsKey = "installedModelVersions"

    // MARK: - Initialization
    private init() {
        lastCheckDate = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    // MARK: - Update Checking

    /// Check for model updates from HuggingFace
    func checkForUpdates() async {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        updateStatus = "Checking for updates..."

        // Check HuggingFace API directly
        let models = await checkHuggingFaceAPI()

        if !models.isEmpty {
            latestModels = models.first?.siblings?.map { $0.rfilename } ?? []

            // Compare with locally installed versions
            let localVersions = getInstalledModelVersions()
            updateAvailable = hasNewerModels(remote: latestModels, local: localVersions)

            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: lastCheckKey)

            updateStatus = updateAvailable ? "Updates available!" : "All models up to date"
        } else {
            updateStatus = "Could not check for updates"
        }

        isCheckingForUpdates = false
    }

    /// Check HuggingFace API directly for model updates
    func checkHuggingFaceAPI() async -> [HuggingFaceModel] {
        guard let url = URL(string: "\(huggingFaceAPIBase)/\(modelRepo)") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let model = try JSONDecoder().decode(HuggingFaceModel.self, from: data)
            return [model]
        } catch {
            print("HuggingFace API error: \(error)")
            return []
        }
    }

    // MARK: - Version Management

    /// Get locally installed model versions
    private func getInstalledModelVersions() -> [String: Date] {
        UserDefaults.standard.dictionary(forKey: installedVersionsKey) as? [String: Date] ?? [:]
    }

    /// Save installed model version
    func recordModelInstallation(model: String) {
        var versions = getInstalledModelVersions()
        versions[model] = Date()
        UserDefaults.standard.set(versions, forKey: installedVersionsKey)
    }

    /// Check if remote has newer models
    private func hasNewerModels(remote: [String], local: [String: Date]) -> Bool {
        // Simple check: are there models we don't have?
        for model in remote {
            if local[model] == nil {
                return true
            }
        }
        return false
    }

    // MARK: - LaunchAgent Management

    /// Install LaunchAgent for automatic model checking
    func installLaunchAgent() throws {
        let launchAgentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")

        try FileManager.default.createDirectory(at: launchAgentDir, withIntermediateDirectories: true)

        let plistPath = launchAgentDir.appendingPathComponent("com.crackedlocalwhisper.modelupdater.plist")

        let updateScriptPath = getUpdateScriptPath()

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.crackedlocalwhisper.modelupdater</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/swift</string>
                <string>\(updateScriptPath.path)</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>3</integer>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
            <key>StandardOutPath</key>
            <string>\(getLogPath().path)</string>
            <key>StandardErrorPath</key>
            <string>\(getLogPath().path)</string>
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """

        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)

        // Create the update script
        try createUpdateScript()

        // Load the LaunchAgent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath.path]
        try process.run()
        process.waitUntilExit()
    }

    /// Uninstall LaunchAgent
    func uninstallLaunchAgent() throws {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.crackedlocalwhisper.modelupdater.plist")

        // Unload the LaunchAgent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath.path]
        try? process.run()
        process.waitUntilExit()

        // Remove the plist file
        try? FileManager.default.removeItem(at: plistPath)
    }

    /// Check if LaunchAgent is installed
    var isLaunchAgentInstalled: Bool {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.crackedlocalwhisper.modelupdater.plist")
        return FileManager.default.fileExists(atPath: plistPath.path)
    }

    // MARK: - Helper Paths

    private func getUpdateScriptPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CrackedLocalWhisper/update_models.swift")
    }

    private func getLogPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CrackedLocalWhisper/update.log")
    }

    /// Create the model update Swift script
    private func createUpdateScript() throws {
        let scriptPath = getUpdateScriptPath()
        let scriptDir = scriptPath.deletingLastPathComponent()

        try FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)

        let scriptContent = """
        #!/usr/bin/env swift
        // Cracked Local Whisper - Model Update Script
        // This script checks for and downloads new WhisperKit models

        import Foundation

        let huggingFaceAPI = "https://huggingface.co/api/models/argmaxinc/whisperkit-coreml"
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDir = appSupportPath.appendingPathComponent("CrackedLocalWhisper/Models")
        let versionsFile = appSupportPath.appendingPathComponent("CrackedLocalWhisper/model_versions.json")

        struct HuggingFaceResponse: Codable {
            let lastModified: String?
            let siblings: [Sibling]?

            struct Sibling: Codable {
                let rfilename: String
            }
        }

        func log(_ message: String) {
            let date = ISO8601DateFormatter().string(from: Date())
            print("[\\(date)] \\(message)")
        }

        func checkForUpdates() async throws {
            log("Starting model update check...")

            guard let url = URL(string: huggingFaceAPI) else {
                log("Invalid API URL")
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(HuggingFaceResponse.self, from: data)

            log("Repo last modified: \\(response.lastModified ?? "unknown")")

            // Check local versions
            var localVersions: [String: String] = [:]
            if let versionData = try? Data(contentsOf: versionsFile),
               let versions = try? JSONDecoder().decode([String: String].self, from: versionData) {
                localVersions = versions
            }

            let remoteDate = response.lastModified ?? ""
            let localDate = localVersions["lastCheck"] ?? ""

            if remoteDate != localDate {
                log("New models available! Remote: \\(remoteDate), Local: \\(localDate)")

                // Update version file
                localVersions["lastCheck"] = remoteDate
                let versionData = try JSONEncoder().encode(localVersions)
                try versionData.write(to: versionsFile)

                log("Version file updated")
            } else {
                log("No updates available")
            }
        }

        // Run the update check
        Task {
            do {
                try await checkForUpdates()
            } catch {
                log("Error: \\(error.localizedDescription)")
            }
            exit(0)
        }

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
        """

        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)

        // Make script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
    }
}

// MARK: - HuggingFace Model Response
struct HuggingFaceModel: Codable {
    let id: String
    let lastModified: String?
    let siblings: [HuggingFaceSibling]?

    enum CodingKeys: String, CodingKey {
        case id
        case lastModified
        case siblings
    }
}

struct HuggingFaceSibling: Codable {
    let rfilename: String
}
