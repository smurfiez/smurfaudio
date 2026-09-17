import Foundation
import AppKit
import Combine

// MARK: - Semantic Version

/// Represents and compares Semantic Versions (SemVer 2.0.0 compliant subset).
public struct SemanticVersion: Comparable, CustomStringConvertible, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let rawValue: String

    public var description: String { rawValue }

    public init?(_ versionString: String) {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        self.rawValue = trimmed
        var work = trimmed
        if work.lowercased().hasPrefix("v") {
            work.removeFirst()
        }

        // Check for prerelease suffix (e.g. 1.3.0-beta.1)
        let parts = work.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let coreString = String(parts[0])
        if parts.count > 1 {
            self.prerelease = String(parts[1])
        } else {
            self.prerelease = nil
        }

        let components = coreString.split(separator: ".").compactMap { Int($0) }
        guard !components.isEmpty else { return nil }

        self.major = components.count > 0 ? components[0] : 0
        self.minor = components.count > 1 ? components[1] : 0
        self.patch = components.count > 2 ? components[2] : 0
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Versions without prerelease tags are greater than ones with prerelease tags
        // e.g. 1.3.0 > 1.3.0-beta
        if lhs.prerelease == nil && rhs.prerelease != nil { return false }
        if lhs.prerelease != nil && rhs.prerelease == nil { return true }
        if let lp = lhs.prerelease, let rp = rhs.prerelease {
            return lp.compare(rp, options: .numeric) == .orderedAscending
        }

        return false
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease
    }
}

// MARK: - GitHub Release API Models

public struct GitHubReleaseAsset: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let size: Int
    public let browserDownloadURL: URL
    public let contentType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }

    public var isInstallerPkg: Bool {
        name.lowercased().hasSuffix(".pkg")
    }

    public var isDiskImage: Bool {
        name.lowercased().hasSuffix(".dmg")
    }

    public var isZipArchive: Bool {
        name.lowercased().hasSuffix(".zip")
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

public struct GitHubRelease: Codable, Identifiable, Equatable {
    public let id: Int
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let publishedAt: String?
    public let prerelease: Bool
    public let draft: Bool
    public let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case draft
        case assets
    }

    public var cleanVersion: String {
        if tagName.lowercased().hasPrefix("v") {
            return String(tagName.dropFirst())
        }
        return tagName
    }

    public var semanticVersion: SemanticVersion? {
        SemanticVersion(tagName)
    }

    /// Selects the best download asset for macOS installation.
    /// Priority: 1. SmurfAudioInstaller.pkg (installs driver + app), 2. SmurfAudio.dmg, 3. .zip
    public var bestAsset: GitHubReleaseAsset? {
        if let pkg = assets.first(where: { $0.isInstallerPkg }) {
            return pkg
        }
        if let dmg = assets.first(where: { $0.isDiskImage }) {
            return dmg
        }
        if let zip = assets.first(where: { $0.isZipArchive }) {
            return zip
        }
        return assets.first
    }
}

// MARK: - Update Status

public enum UpdateStatus: Equatable {
    case idle
    case checking
    case updateAvailable(GitHubRelease)
    case upToDate
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case readyToInstall(fileURL: URL)
    case failed(String)

    public static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate):
            return true
        case (.updateAvailable(let a), .updateAvailable(let b)):
            return a.id == b.id
        case (.downloading(let p1, _, _), .downloading(let p2, _, _)):
            return abs(p1 - p2) < 0.001
        case (.readyToInstall(let u1), .readyToInstall(let u2)):
            return u1 == u2
        case (.failed(let m1), .failed(let m2)):
            return m1 == m2
        default:
            return false
        }
    }
}

// MARK: - Update Manager

/// Service that checks GitHub Releases, notifies the user of newer versions,
/// and downloads and launches update packages.
public final class UpdateManager: ObservableObject {

    // MARK: User Defaults Keys
    private static let kAutoCheckKey = "SmurfAudioAutoCheckForUpdates"
    private static let kSkippedVersionKey = "SmurfAudioSkippedVersion"
    private static let kLastCheckDateKey = "SmurfAudioLastUpdateCheckDate"

    // MARK: Published State
    @Published public var status: UpdateStatus = .idle
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadedFileURL: URL? = nil
    @Published public var lastCheckDate: Date? = nil
    @Published public var automaticallyChecksForUpdates: Bool {
        didSet {
            UserDefaults.standard.set(automaticallyChecksForUpdates, forKey: Self.kAutoCheckKey)
        }
    }

    public var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: Self.kSkippedVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.kSkippedVersionKey) }
    }

    // MARK: Configuration
    public let repoOwner: String
    public let repoName: String
    public let session: URLSession

    public var currentVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.4.0"
    }

    public var currentSemanticVersion: SemanticVersion {
        SemanticVersion(currentVersionString) ?? SemanticVersion("1.4.0")!
    }

    public var isUpdateAvailable: Bool {
        if case .updateAvailable = status { return true }
        if case .downloading = status { return true }
        if case .readyToInstall = status { return true }
        return false
    }

    // MARK: Initialization
    public init(
        repoOwner: String = "smurfiez",
        repoName: String = "smurfaudio",
        session: URLSession = .shared
    ) {
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.session = session

        // Default to auto-check enabled if unset
        if UserDefaults.standard.object(forKey: Self.kAutoCheckKey) == nil {
            self.automaticallyChecksForUpdates = true
        } else {
            self.automaticallyChecksForUpdates = UserDefaults.standard.bool(forKey: Self.kAutoCheckKey)
        }

        if let savedDate = UserDefaults.standard.object(forKey: Self.kLastCheckDateKey) as? Date {
            self.lastCheckDate = savedDate
        }
    }

    // MARK: Check for Updates

    /// Checks the GitHub Releases API for the latest published release.
    /// - Parameter silent: If true, suppresses modal popups if no update is available or on error.
    public func checkForUpdates(silent: Bool = false) async {
        let shouldProceed: Bool = await MainActor.run {
            guard status != .checking else { return false }
            if case .downloading = status { return false }
            if case .readyToInstall = status { return false }
            status = .checking
            return true
        }

        guard shouldProceed else { return }

        let endpointString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: endpointString) else {
            let err = "Invalid GitHub releases endpoint URL"
            await MainActor.run {
                self.status = .failed(err)
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SmurfAudio-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "UpdateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid network response"])
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 404 {
                    throw NSError(domain: "UpdateManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No releases found on GitHub."])
                }
                throw NSError(domain: "UpdateManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(httpResponse.statusCode)"])
            }

            let decoder = JSONDecoder()
            let release = try decoder.decode(GitHubRelease.self, from: data)

            let now = Date()
            UserDefaults.standard.set(now, forKey: Self.kLastCheckDateKey)

            guard let remoteSemVer = release.semanticVersion else {
                throw NSError(domain: "UpdateManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not parse release tag: \(release.tagName)"])
            }

            await MainActor.run {
                self.lastCheckDate = now
                // Check if newer than current
                if remoteSemVer > self.currentSemanticVersion {
                    // If this version was explicitly skipped and check is silent, don't nag
                    if silent && release.cleanVersion == self.skippedVersion {
                        self.status = .idle
                        return
                    }

                    self.latestRelease = release
                    self.status = .updateAvailable(release)

                    // If user triggered manually, show update window
                    if !silent {
                        UpdateWindowController.shared.show(updateManager: self)
                    }
                } else {
                    self.latestRelease = release
                    self.status = .upToDate
                }
            }

        } catch {
            let message = error.localizedDescription
            await MainActor.run {
                self.status = .failed(message)
                if !silent {
                    UpdateWindowController.shared.show(updateManager: self)
                }
            }
        }
    }

    // MARK: Download Update

    /// Streams the download of the chosen asset or best available asset.
    public func downloadUpdate(asset: GitHubReleaseAsset? = nil) async {
        guard let release = latestRelease else { return }
        guard let targetAsset = asset ?? release.bestAsset else {
            await MainActor.run {
                self.status = .failed("No downloadable asset found for release.")
            }
            return
        }

        await MainActor.run {
            self.downloadProgress = 0.0
            self.status = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: Int64(targetAsset.size))
        }

        var request = URLRequest(url: targetAsset.browserDownloadURL)
        request.setValue("SmurfAudio-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120

        do {
            let (asyncBytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "UpdateManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to download asset from GitHub"])
            }

            let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : Int64(targetAsset.size)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SmurfAudioUpdate_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let destinationURL = tempDir.appendingPathComponent(targetAsset.name)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: destinationURL)

            var bytesWritten: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(65536) // 64KB chunks

            for try await byte in asyncBytes {
                buffer.append(byte)
                bytesWritten += 1

                if buffer.count >= 65536 {
                    try fileHandle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)

                    let progress = expectedLength > 0 ? Double(bytesWritten) / Double(expectedLength) : 0.5
                    let currentWritten = bytesWritten
                    await MainActor.run {
                        self.downloadProgress = progress
                        self.status = .downloading(progress: progress, bytesWritten: currentWritten, totalBytes: expectedLength)
                    }
                }
            }

            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
            }
            try fileHandle.close()

            await MainActor.run {
                self.downloadProgress = 1.0
                self.downloadedFileURL = destinationURL
                self.status = .readyToInstall(fileURL: destinationURL)
            }

        } catch {
            await MainActor.run {
                self.status = .failed("Download failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Install & Relaunch

    /// Opens the downloaded update installer (.pkg or .dmg) and prepares for update.
    public func installAndRelaunch() {
        guard case .readyToInstall(let fileURL) = status else { return }

        // Launch the downloaded file
        NSWorkspace.shared.open(fileURL)

        // For .pkg installers, bring installer to front
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Helper Actions

    public func skipCurrentVersion() {
        if let rel = latestRelease {
            skippedVersion = rel.cleanVersion
        }
        status = .idle
        UpdateWindowController.shared.close()
    }

    public func openReleasePage() {
        if let rel = latestRelease {
            NSWorkspace.shared.open(rel.htmlURL)
        } else {
            if let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    public func reset() {
        status = .idle
        downloadProgress = 0.0
        downloadedFileURL = nil
    }
}
