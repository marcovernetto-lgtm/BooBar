import AppKit
import CryptoKit
import Security
import os

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              pieces.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = pieces.map { Int($0)! }
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        let digest: String?
        let size: Int
    }
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    func update(from current: String) -> Asset? {
        guard !draft, !prerelease, let next = ReleaseVersion(tag_name), let installed = ReleaseVersion(current), next > installed else { return nil }
        return assets.first {
            $0.name == "BooBar-\(tag_name.dropFirst(tag_name.hasPrefix("v") ? 1 : 0))-universal.dmg" &&
            $0.browser_download_url.scheme == "https" && $0.browser_download_url.host == "github.com" &&
            $0.browser_download_url.path.hasPrefix("/marcovernetto-lgtm/BooBar/releases/download/") &&
            $0.size > 0 && $0.size <= 50_000_000 && $0.digest?.hasPrefix("sha256:") == true
        }
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    @Published var enabled = UserDefaults.standard.object(forKey: "BooBar.autoUpdate") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "BooBar.autoUpdate")
            if enabled { Task { await check() } }
        }
    }
    @Published private(set) var status: BooText = .updateReady
    @Published private(set) var busy = false
    private let log = Logger(subsystem: "it.marcovernetto.BooBar", category: "Updater")
    private var timer: Timer?
    private var task: Task<Void, Never>?
    func start() {
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await self?.check()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in guard self?.enabled == true else { return }; await self?.check() }
        }
        timer?.tolerance = 300
    }
    func stop() { task?.cancel(); timer?.invalidate() }
    func check(manual: Bool = false) async {
        guard !busy, enabled || manual else { return }
        busy = true; status = .updateChecking
        defer { busy = false }
        var workspace: URL?
        var mount: URL?
        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 180
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/marcovernetto-lgtm/BooBar/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("BooBar", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.invalid }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
            guard let latest = ReleaseVersion(release.tag_name), let installed = ReleaseVersion(current) else { throw UpdateFailure.invalid }
            guard latest > installed, !release.draft, !release.prerelease else { status = .updateCurrent; return }
            guard let asset = release.update(from: current) else { throw UpdateFailure.invalid }
            guard enabled || manual else { status = .updateReady; return }
            status = .updateDownloading
            log.notice("Downloading release \(release.tag_name, privacy: .public)")
            let (download, downloadedResponse) = try await session.download(from: asset.browser_download_url)
            defer { try? FileManager.default.removeItem(at: download) }
            guard (downloadedResponse as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.invalid }
            let content = try Data(contentsOf: download, options: .mappedIfSafe)
            guard content.count == asset.size,
                  "sha256:" + SHA256.hash(data: content).map({ String(format: "%02x", $0) }).joined() == asset.digest else { throw UpdateFailure.invalid }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BooBar-update-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            workspace = folder
            let image = folder.appendingPathComponent("update.dmg")
            try FileManager.default.moveItem(at: download, to: image)
            let volume = folder.appendingPathComponent("volume")
            try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: false)
            try await Self.run("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", volume.path, image.path])
            mount = volume
            let source = volume.appendingPathComponent("BooBar.app")
            try Self.verify(source, matches: Bundle.main.bundleURL, version: release.tag_name)
            let staged = folder.appendingPathComponent("BooBar.app")
            try await Self.run("/usr/bin/ditto", [source.path, staged.path])
            try Self.verify(staged, matches: Bundle.main.bundleURL, version: release.tag_name)
            try await Self.run("/usr/bin/hdiutil", ["detach", volume.path]); mount = nil
            guard enabled || manual else { status = .updateReady; try? FileManager.default.removeItem(at: folder); return }
            log.notice("Digest and installed signing requirement verified for \(release.tag_name, privacy: .public)")
            try install(staged, folder: folder)
            workspace = nil // The helper owns the workspace after successful launch.
        } catch {
            if let mount { try? await Self.run("/usr/bin/hdiutil", ["detach", mount.path]) }
            if let workspace { try? FileManager.default.removeItem(at: workspace) }
            log.error("Automatic update failed: \(error.localizedDescription, privacy: .public)")
            status = .updateFailed
        }
    }

    // Require the installed app's designated signing requirement, not just a GitHub checksum.
    static func verify(_ candidate: URL, matches installed: URL, version: String) throws {
        var own: SecStaticCode?; var downloaded: SecStaticCode?; var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(installed as CFURL, [], &own) == errSecSuccess, let own,
              SecCodeCopyDesignatedRequirement(own, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(candidate as CFURL, [], &downloaded) == errSecSuccess, let downloaded,
              SecStaticCodeCheckValidity(downloaded, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate), requirement) == errSecSuccess,
              let bundle = Bundle(url: candidate), bundle.bundleIdentifier == "it.marcovernetto.Hidebar",
              let actual = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              ReleaseVersion(actual) == ReleaseVersion(version), ReleaseVersion(actual) != nil else { throw UpdateFailure.invalid }
        if let minimum = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String {
            let numbers = minimum.split(separator: ".").compactMap { Int($0) }
            guard (1...3).contains(numbers.count), numbers.count == minimum.split(separator: ".").count else { throw UpdateFailure.invalid }
            let os = OperatingSystemVersion(majorVersion: numbers[0], minorVersion: numbers.count > 1 ? numbers[1] : 0,
                patchVersion: numbers.count > 2 ? numbers[2] : 0)
            guard ProcessInfo.processInfo.isOperatingSystemAtLeast(os) else { throw UpdateFailure.invalid }
        }
        #if arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "arm64"
        #endif
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        guard let executable = bundle.executableURL else { throw UpdateFailure.invalid }
        process.arguments = ["-verify_arch", architecture, executable.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateFailure.invalid }
    }

    private func install(_ staged: URL, folder: URL) throws {
        let target = Bundle.main.bundleURL.standardizedFileURL
        let parent = target.deletingLastPathComponent()
        let allowed = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        guard allowed.contains(parent), FileManager.default.isWritableFile(atPath: parent.path),
              FileManager.default.isWritableFile(atPath: target.path) else { throw UpdateFailure.invalid }
        let script = folder.appendingPathComponent("install.sh")
        try Self.helper.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), staged.path, target.path, folder.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        log.notice("Starting background replacement and relaunch")
        status = .updateInstalling
        NSApp.terminate(nil)
    }

    // Keep the previous app until the replacement is in place; never interpolate paths into shell code.
    static let helper = """
    set -eu
    pid="$1"; source="$2"; target="$3"; work="$4"
    while kill -0 "$pid" 2>/dev/null; do sleep 1; done
    backup="$work/previous.app"
    next="${target}.update-$(basename "$work")"
    if /usr/bin/ditto "$source" "$next"; then
        if mv "$target" "$backup"; then
            if ! mv "$next" "$target"; then mv "$backup" "$target"; fi
        fi
    fi
    rm -rf "$next"
    if ! /usr/bin/open -gj "$target" --args --background; then
        if [ -d "$backup" ]; then
            rm -rf "$target"
            mv "$backup" "$target"
            /usr/bin/open -gj "$target" --args --background || true
        fi
    fi
    # Retain the previous signed app for recovery; remove only the download and staging copy.
    rm -rf "$source" "$work/update.dmg"

    """
    nonisolated static func run(_ executable: String, _ arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw UpdateFailure.invalid }
        }.value
    }
}
private enum UpdateFailure: Error { case invalid }
