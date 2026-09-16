import Testing
import Foundation
@testable import SmurfAudio

// MARK: - Mock URL Protocol for Network Tests

final class MockUpdateURLProtocol: URLProtocol {
    static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockUpdateURLProtocol.mockHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockUpdateURLProtocol", code: -1, userInfo: nil))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - UpdateManager Tests

@Suite("UpdateManager Tests", .serialized)
struct UpdateManagerTests {

    // MARK: Semantic Version Parsing & Comparison

    @Test("SemanticVersion parsing valid and invalid strings")
    func testSemanticVersionParsing() {
        let v1 = SemanticVersion("1.3.0")
        #expect(v1 != nil)
        #expect(v1?.major == 1)
        #expect(v1?.minor == 3)
        #expect(v1?.patch == 0)
        #expect(v1?.prerelease == nil)

        let vWithPrefix = SemanticVersion("v2.1.4")
        #expect(vWithPrefix != nil)
        #expect(vWithPrefix?.major == 2)
        #expect(vWithPrefix?.minor == 1)
        #expect(vWithPrefix?.patch == 4)

        let vPre = SemanticVersion("v1.4.0-beta.2")
        #expect(vPre != nil)
        #expect(vPre?.major == 1)
        #expect(vPre?.minor == 4)
        #expect(vPre?.patch == 0)
        #expect(vPre?.prerelease == "beta.2")

        let invalid = SemanticVersion("not-a-version")
        #expect(invalid == nil)

        let empty = SemanticVersion("")
        #expect(empty == nil)
    }

    @Test("SemanticVersion comparison rules")
    func testSemanticVersionComparison() {
        let v1_3_0 = SemanticVersion("1.3.0")!
        let v1_3_1 = SemanticVersion("1.3.1")!
        let v1_4_0 = SemanticVersion("1.4.0")!
        let v2_0_0 = SemanticVersion("2.0.0")!
        let v1_3_0_prefix = SemanticVersion("v1.3.0")!
        let v1_4_0_beta = SemanticVersion("1.4.0-beta.1")!
        let v1_4_0_rc = SemanticVersion("1.4.0-rc.1")!

        #expect(v1_3_0 < v1_3_1)
        #expect(v1_3_1 < v1_4_0)
        #expect(v1_4_0 < v2_0_0)
        #expect(v1_3_0 == v1_3_0_prefix)
        #expect(v1_3_1 > v1_3_0)

        // Prerelease comparisons
        #expect(v1_4_0_beta < v1_4_0)
        #expect(v1_4_0_beta < v1_4_0_rc)
        #expect(v1_4_0 > v1_4_0_rc)
    }

    // MARK: GitHub Release JSON Decoding

    @Test("GitHubRelease JSON decoding and asset prioritization")
    func testGitHubReleaseDecoding() throws {
        let json = """
        {
            "id": 123456,
            "tag_name": "v1.4.0",
            "name": "SmurfAudio v1.4.0",
            "body": "## New Features\\n- Auto updater\\n- CI/CD workflow",
            "html_url": "https://github.com/smurfiez/smurfaudio/releases/tag/v1.4.0",
            "published_at": "2026-09-16T12:00:00Z",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "id": 1,
                    "name": "SmurfAudio-Mac.zip",
                    "size": 5242880,
                    "browser_download_url": "https://github.com/smurfiez/smurfaudio/releases/download/v1.4.0/SmurfAudio-Mac.zip",
                    "content_type": "application/zip"
                },
                {
                    "id": 2,
                    "name": "SmurfAudio.dmg",
                    "size": 8388608,
                    "browser_download_url": "https://github.com/smurfiez/smurfaudio/releases/download/v1.4.0/SmurfAudio.dmg",
                    "content_type": "application/x-apple-diskimage"
                },
                {
                    "id": 3,
                    "name": "SmurfAudioInstaller.pkg",
                    "size": 6291456,
                    "browser_download_url": "https://github.com/smurfiez/smurfaudio/releases/download/v1.4.0/SmurfAudioInstaller.pkg",
                    "content_type": "application/octet-stream"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: json)

        #expect(release.id == 123456)
        #expect(release.tagName == "v1.4.0")
        #expect(release.cleanVersion == "1.4.0")
        #expect(release.semanticVersion == SemanticVersion("1.4.0"))
        #expect(release.assets.count == 3)

        // Asset prioritization: .pkg takes highest precedence because it bundles BlackHole driver
        let best = release.bestAsset
        #expect(best != nil)
        #expect(best?.name == "SmurfAudioInstaller.pkg")
        #expect(best?.isInstallerPkg == true)

        let dmgAsset = release.assets.first(where: { $0.isDiskImage })
        #expect(dmgAsset != nil)
        #expect(dmgAsset?.name == "SmurfAudio.dmg")

        let zipAsset = release.assets.first(where: { $0.isZipArchive })
        #expect(zipAsset != nil)
        #expect(zipAsset?.name == "SmurfAudio-Mac.zip")
    }

    // MARK: Mock Network Check for Updates

    @Test("UpdateManager detects newer release via GitHub API")
    func testCheckForUpdatesDetectsNewerVersion() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let mockJSON = """
        {
            "id": 999,
            "tag_name": "v99.0.0",
            "name": "SmurfAudio v99.0.0",
            "body": "Future update notes",
            "html_url": "https://github.com/smurfiez/smurfaudio/releases/tag/v99.0.0",
            "published_at": "2026-09-16T12:00:00Z",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "id": 991,
                    "name": "SmurfAudioInstaller.pkg",
                    "size": 1048576,
                    "browser_download_url": "https://github.com/smurfiez/smurfaudio/releases/download/v99.0.0/SmurfAudioInstaller.pkg",
                    "content_type": "application/octet-stream"
                }
            ]
        }
        """.data(using: .utf8)!

        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockJSON)
        }

        let manager = UpdateManager(
            repoOwner: "smurfiez",
            repoName: "smurfaudio",
            session: mockSession
        )

        // Clear any skipped version
        manager.skippedVersion = nil

        await manager.checkForUpdates(silent: true)

        #expect(manager.isUpdateAvailable == true)
        #expect(manager.latestRelease?.tagName == "v99.0.0")
        if case .updateAvailable(let rel) = manager.status {
            #expect(rel.cleanVersion == "99.0.0")
        } else {
            Issue.record("Expected status to be updateAvailable")
        }
    }

    @Test("UpdateManager reports upToDate when remote version is older or same")
    func testCheckForUpdatesReportsUpToDate() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockUpdateURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let mockJSON = """
        {
            "id": 100,
            "tag_name": "v1.0.0",
            "name": "SmurfAudio v1.0.0",
            "body": "Older release notes",
            "html_url": "https://github.com/smurfiez/smurfaudio/releases/tag/v1.0.0",
            "published_at": "2026-09-13T12:00:00Z",
            "prerelease": false,
            "draft": false,
            "assets": []
        }
        """.data(using: .utf8)!

        MockUpdateURLProtocol.mockHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, mockJSON)
        }

        let manager = UpdateManager(
            repoOwner: "smurfiez",
            repoName: "smurfaudio",
            session: mockSession
        )

        await manager.checkForUpdates(silent: true)

        #expect(manager.isUpdateAvailable == false)
        #expect(manager.status == .upToDate)
    }

    @Test("UpdateManager skip version behavior")
    func testSkipVersion() {
        let manager = UpdateManager()
        let previousSkipped = manager.skippedVersion

        let testRelease = GitHubRelease(
            id: 888,
            tagName: "v2.5.0",
            name: "v2.5.0",
            body: "Notes",
            htmlURL: URL(string: "https://github.com")!,
            publishedAt: nil,
            prerelease: false,
            draft: false,
            assets: []
        )

        manager.latestRelease = testRelease
        manager.skipCurrentVersion()

        #expect(manager.skippedVersion == "2.5.0")
        #expect(manager.status == .idle)

        // Restore skipped state
        manager.skippedVersion = previousSkipped
    }
}
