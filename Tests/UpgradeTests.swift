import XCTest
import AppKit
import Carbon
@testable import BooBar

final class UpgradeTests: XCTestCase {
    func testHoverGraceAndKeyboardPin() {
        let start = Date(timeIntervalSince1970: 100)
        var state = BarInteraction(lastPresence: start)
        XCTAssertFalse(state.shouldCollapse(now: start.addingTimeInterval(1), inBar: false, pressed: false, popup: false))
        XCTAssertFalse(state.shouldCollapse(now: start.addingTimeInterval(2), inBar: false, pressed: false, popup: true))
        XCTAssertFalse(state.shouldCollapse(now: start.addingTimeInterval(3), inBar: false, pressed: true, popup: false))
        XCTAssertTrue(state.shouldCollapse(now: start.addingTimeInterval(5), inBar: false, pressed: false, popup: false))
        state.pinned = true
        XCTAssertFalse(state.shouldCollapse(now: start.addingTimeInterval(50), inBar: false, pressed: false, popup: false))
        XCTAssertEqual(BarInteraction.interval(expanded: false, nearBar: false), 0.5)
        XCTAssertEqual(BarInteraction.interval(expanded: true, nearBar: false), 0.1)
        XCTAssertEqual(BarInteraction.interval(expanded: false, nearBar: true), 0.1)
    }
    func testLoginAndUpdaterRestartNeverOpenSettings() {
        for welcomed in [true, false] {
            for authorized in [true, false] {
                XCTAssertFalse(BarInteraction.opensSettings(login: true, background: false, welcomed: welcomed, authorized: authorized))
                XCTAssertFalse(BarInteraction.opensSettings(login: false, background: true, welcomed: welcomed, authorized: authorized))
            }
        }
        XCTAssertTrue(BarInteraction.opensSettings(login: false, background: false, welcomed: false, authorized: true))
        XCTAssertTrue(BarInteraction.opensSettings(login: false, background: false, welcomed: true, authorized: false))
    }
    func testShortcutRequiresModifierAndRoundTrips() throws {
        func event(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                timestamp: 0, windowNumber: 0, context: nil, characters: "b", charactersIgnoringModifiers: "b", isARepeat: false, keyCode: 11))
        }
        XCTAssertNil(Shortcut.capture(try event([])))
        let shortcut = try XCTUnwrap(Shortcut.capture(try event([.command, .shift])))
        XCTAssertEqual(shortcut.label, "⇧⌘B")
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)), shortcut)
    }
    @MainActor
    func testNativeHotkeyConflictPreservesExistingRegistration() {
        let first = GlobalShortcut(), second = GlobalShortcut(), probe = GlobalShortcut()
        defer { first.stop(); second.stop(); probe.stop() }
        let mods = UInt32(cmdKey | optionKey | controlKey)
        let a = Shortcut(key: 80, modifiers: mods, label: "F19")
        let b = Shortcut(key: 79, modifiers: mods, label: "F18")
        XCTAssertTrue(first.register(a))
        XCTAssertTrue(first.register(a))
        XCTAssertTrue(second.register(b))
        XCTAssertFalse(first.register(b))
        XCTAssertFalse(probe.register(a))
        XCTAssertTrue(first.register(nil))
        XCTAssertTrue(probe.register(a))
    }
    func testReleaseSelectionRejectsDowngradesPrereleasesAndUntrustedURLs() throws {
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.7.9")), try XCTUnwrap(ReleaseVersion("v0.7.10")))
        XCTAssertNil(ReleaseVersion("0.8.0-beta"))
        XCTAssertNil(ReleaseVersion("1.2"))
        func release(_ url: String, prerelease: Bool = false) throws -> GitHubRelease {
            let object: [String: Any] = ["tag_name": "v0.8.0", "draft": false, "prerelease": prerelease,
              "assets": [["name": "BooBar-0.8.0-universal.dmg", "browser_download_url": url,
                "digest": "sha256:" + String(repeating: "0", count: 64), "size": 1234]]]
            return try JSONDecoder().decode(GitHubRelease.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let good = "https://github.com/marcovernetto-lgtm/BooBar/releases/download/v0.8.0/BooBar-0.8.0-universal.dmg"
        XCTAssertNotNil(try release(good).update(from: "0.7.0"))
        XCTAssertNil(try release(good).update(from: "0.8.0"))
        XCTAssertNil(try release(good).update(from: "0.9.0"))
        XCTAssertNil(try release(good, prerelease: true).update(from: "0.7.0"))
        XCTAssertNil(try release("https://example.com/update.dmg").update(from: "0.7.0"))
    }
    @MainActor
    func testSignatureVerificationRejectsAnotherSigningIdentity() throws {
        let installed = URL(fileURLWithPath: "/Applications/BooBar.app")
        let current = try XCTUnwrap(Bundle(url: installed)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        try UpdateManager.verify(installed, matches: installed, version: current)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let candidate = directory.appendingPathComponent("BooBar.app")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.copyItem(at: installed, to: candidate)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", candidate.path]
        process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertThrowsError(try UpdateManager.verify(candidate, matches: installed, version: current))
        XCTAssertThrowsError(try UpdateManager.verify(installed, matches: installed, version: "999.0.0"))
    }
    @MainActor
    func testInstallerReplacesAndRollsBackUsingPathsWithSpaces() throws {
        for failSwap in [false, true] {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BooBar test " + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let source = folder.appendingPathComponent("new app"), target = folder.appendingPathComponent("installed app")
            for path in [source, target] { try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true) }
            try "new".write(to: source.appendingPathComponent("sentinel"), atomically: true, encoding: .utf8)
            try "old".write(to: target.appendingPathComponent("sentinel"), atomically: true, encoding: .utf8)
            let work = folder.appendingPathComponent("work"); try FileManager.default.createDirectory(at: work, withIntermediateDirectories: false)
            let script = folder.appendingPathComponent("installer.sh")
            var code = UpdateManager.helper.replacingOccurrences(of: "/usr/bin/open -gj \"$target\" --args --background", with: "/usr/bin/true")
            if failSwap { code = code.replacingOccurrences(of: "if ! mv \"$next\" \"$target\"; then", with: "if ! /usr/bin/false; then") }
            try code.write(to: script, atomically: true, encoding: .utf8)
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path, "99999999", source.path, target.path, work.path]
            try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
            XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("sentinel"), encoding: .utf8), failSwap ? "old" : "new")
        }
    }
}
