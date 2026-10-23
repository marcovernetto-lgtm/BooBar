import XCTest
import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import MenuBarBridge
@testable import BooBar

final class BooBarTests: XCTestCase {
    func testDraggingAcrossBothWallsAssignsThreeZones() throws {
        var zones = Zones()
        try zones.arrange([
            .init(bundleID: "left", x: 10), .init(bundleID: "middle", x: 30), .init(bundleID: "right", x: 50)
        ], permanentWall: 20, mainWall: 40)
        XCTAssertEqual(zones.hidden(in: .collapsed), ["left", "middle"])
        XCTAssertEqual(zones.hidden(in: .expanded), ["left"])
        XCTAssertTrue(zones.hidden(in: .arranging).isEmpty)
    }

    func testAnAppWithOneVisibleIconRemainsVisible() throws {
        var zones = Zones()
        try zones.arrange([.init(bundleID: "shared", x: 10), .init(bundleID: "shared", x: 50)],
                          permanentWall: 20, mainWall: 40)
        XCTAssertEqual(zones.assignments["shared"], .visible)
    }

    func testReversedWallsDoNotOverwriteExistingZones() {
        var zones = Zones(assignments: ["existing": .temporary])
        XCTAssertThrowsError(try zones.arrange([.init(bundleID: "existing", x: 5)],
                                               permanentWall: 40, mainWall: 20))
        XCTAssertEqual(zones.assignments["existing"], .temporary)
    }

    func testResetRestoresEverythingAndPersistsAcrossLaunches() throws {
        var zones = Zones(assignments: ["one": .alwaysHidden, "two": .temporary])
        zones.reset()
        let saved = try JSONEncoder().encode(zones)
        let restored = try JSONDecoder().decode(Zones.self, from: saved)
        XCTAssertTrue(restored.suspended)
        XCTAssertTrue(restored.assignments.isEmpty)
        XCTAssertTrue(restored.hidden(in: .collapsed).isEmpty)
    }

    func testMissingOrNewApplicationsDoNotAcquireAnImplicitHiddenRule() throws {
        var zones = Zones(assignments: ["previous": .alwaysHidden])
        try zones.arrange([.init(bundleID: "new", x: 50)], permanentWall: 20, mainWall: 40)
        XCTAssertEqual(zones.assignments["new"], .visible)
        XCTAssertEqual(zones.assignments["previous"], .alwaysHidden)
        XCTAssertNil(zones.assignments["notObserved"])
    }

    func testNativeAllowListUsesSigningIdentityAndPreservesVisibleSharedIdentities() {
        let nivo = MenuBarIdentity(bundleID: "com.marco.MacDashboard", signingID: "MacDashboard")
        let other = MenuBarIdentity(bundleID: "other.app", signingID: "other.signature")
        XCTAssertEqual(MenuBarIdentity.allowed([nivo, other], hiding: ["other.app"]),
                       ["com.marco.MacDashboard", "MacDashboard"])
        XCTAssertEqual(MenuBarIdentity.allowed([nivo, other], hiding: ["com.marco.MacDashboard"]),
                       ["other.app", "other.signature"])
        let shared = MenuBarIdentity(bundleID: "visible.app", signingID: "MacDashboard")
        XCTAssertTrue(MenuBarIdentity.allowed([nivo, shared], hiding: ["com.marco.MacDashboard"])
            .contains("MacDashboard"))
    }

    func testNativeInterfaceExistsOnInstalledMacOS27() {
        XCTAssertTrue(HBMenuBar.available)
    }

    @MainActor
    func testNativeAssertionIsAcceptedAndCanBeReleased() async {
        let engine = HBMenuBar()
        defer { engine.restore() }
        var allowed = MenuBarIdentity.allowed(
            NSWorkspace.shared.runningApplications.compactMap(MenuBarIdentity.read), hiding: [])
        if let own = Bundle.main.bundleIdentifier { allowed.insert(own) }
        let completion = expectation(description: "macOS accetta la configurazione nativa")
        engine.allowBundles(allowed.sorted()) { error in
            XCTAssertNil(error)
            completion.fulfill()
        }
        let result = await XCTWaiter.fulfillment(of: [completion], timeout: 5)
        XCTAssertEqual(result, .completed)
    }


    @MainActor
    func testMascotLoopMovesAndRespectsReducedMotion() {
        XCTAssertFalse(BooVector.letter.isEmpty)
        XCTAssertFalse(BooVector.palm.isEmpty)
        XCTAssertEqual(MascotPose.at(0), MascotPose.at(MascotPose.duration))
        XCTAssertEqual(MascotPose.at(1, reducedMotion: true), .resting)
        XCTAssertEqual(MascotPose.at(4, reducedMotion: true), .resting)
        XCTAssertEqual(MascotPose.at(MascotPose.duration - 0.001).gaze,
                       MascotPose.at(0).gaze, accuracy: 0.001)
        XCTAssertGreaterThan(MascotPose.at(2).leftHand, 0.95)
        XCTAssertGreaterThan(MascotPose.at(2).rightHand, 0.95)
    }

    func testHandsEyesAndBlinksMoveIndependently() {
        let staggered = MascotPose.at(1.45)
        XCTAssertGreaterThan(staggered.leftHand, staggered.rightHand + 0.3)
        let peek = MascotPose.at(2.85)
        XCTAssertLessThan(peek.leftHand, 0.2)
        XCTAssertGreaterThan(peek.rightHand, 0.6)
        let glance = MascotPose.at(0.9)
        XCTAssertEqual(glance.leftHand, 0)
        XCTAssertEqual(glance.rightHand, 0)
        XCTAssertNotEqual(glance.gaze, MascotPose.at(0).gaze)
        XCTAssertGreaterThan(MascotPose.at(0.61).leftBlink, MascotPose.at(0.61).rightBlink)
    }

    @MainActor
    func testExportsActualMascotFramesAsLoopingGIF() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".build/previews"), withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Resources/Brand/boobar-loop.gif")
        let frameCount = 64
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
            UTType.gif.identifier as CFString, frameCount, nil))
        CGImageDestinationSetProperties(destination,
            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var distinctFrames = Set<Data>()
        for index in 0..<frameCount {
            let host = NSHostingView(rootView: MascotFrame(pose: .at(Double(index) / 10))
                .background(BooPalette.background))
            host.frame = CGRect(x: 0, y: 0, width: 300, height: 145)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            distinctFrames.insert(data)
            if [0,6,15,20,28,39,47].contains(index) {
                try data.write(to: root.appendingPathComponent(".build/previews/mascot-\(index).png"))
            }
            CGImageDestinationAddImage(destination, try XCTUnwrap(bitmap.cgImage),
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
        }
        XCTAssertGreaterThan(distinctFrames.count, 25, "Il loop deve contenere movimento reale e articolato")
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), frameCount)
        let properties = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [String: Any])
        let gif = try XCTUnwrap(properties[kCGImagePropertyGIFDictionary as String] as? [String: Any])
        XCTAssertEqual(gif[kCGImagePropertyGIFLoopCount as String] as? Int, 0)

        let layers = BooVector.layers(for: .resting)
        let paths = layers.map { layer in
            let paint = String(format: "#%06x", layer.color)
            let style = layer.stroke > 0 ? "fill=\"none\" stroke=\"\(paint)\" stroke-width=\"\(layer.stroke)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"" : "fill=\"\(paint)\" fill-rule=\"evenodd\""
            return "<path id=\"\(layer.name)\" d=\"\(svgPath(layer.path))\" \(style)/>"
        }.joined(separator: "\n")
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 400 190\"><title>BooB — BooBar</title><rect id=\"preview-background\" width=\"400\" height=\"190\" fill=\"#0e171b\"/>\n" + paths + "\n</svg>"
        try svg.write(to: root.appendingPathComponent("Resources/Brand/boob-mascot-v2.svg"), atomically: true, encoding: .utf8)
    }

    private func svgPath(_ path: Path) -> String {
        var result = ""
        path.cgPath.applyWithBlock { element in
            let e = element.pointee
            func xy(_ index: Int) -> String { String(format: "%.3f %.3f", e.points[index].x, e.points[index].y) }
            switch e.type {
            case .moveToPoint: result += "M" + xy(0)
            case .addLineToPoint: result += "L" + xy(0)
            case .addQuadCurveToPoint: result += "Q" + xy(0) + " " + xy(1)
            case .addCurveToPoint: result += "C" + xy(0) + " " + xy(1) + " " + xy(2)
            case .closeSubpath: result += "Z"
            @unknown default: break
            }
        }
        return result
    }

    func testEveryUIStringHasBothTranslationsAndLanguagePersists() throws {
        let suite = "BooBarTests.language.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: "BooBar.language")
            XCTAssertEqual(AppLanguage.load(from: defaults), language)
            for key in BooText.allCases { XCTAssertFalse(language.text(key).isEmpty) }
        }
        defaults.set("unsupported", forKey: "BooBar.language")
        XCTAssertTrue(AppLanguage.allCases.contains(AppLanguage.load(from: defaults)))
        XCTAssertEqual(AppLanguage.english.text(.settings), "Settings")
        XCTAssertEqual(AppLanguage.italian.text(.settings), "Impostazioni")
        XCTAssertNotEqual(AppLanguage.italian.text(.reversedWalls), AppLanguage.english.text(.reversedWalls))
    }

    @MainActor
    func testSettingsRenderInBothSystemAppearances() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in [NSAppearance.Name.aqua, .darkAqua] {
          for authorized in [false, true] {
           for language in AppLanguage.allCases {
            let controller = BooBarController(language: language)
            controller.authorized = authorized
            let host = NSHostingView(rootView: SettingsView(controller: controller)
                .environment(\.colorScheme, name == .darkAqua ? .dark : .light))
            host.appearance = NSAppearance(named: name)
            let size = host.fittingSize
            XCTAssertGreaterThan(size.width, 500)
            XCTAssertGreaterThan(size.height, 300)
            host.frame = CGRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            guard let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                return XCTFail("Impossibile catturare la vista nativa")
            }
            host.cacheDisplay(in: host.bounds, to: image)
            let data = try XCTUnwrap(image.representation(using: .png, properties: [:]))
            let appearance = name == .aqua ? "light" : "dark"
            let state = authorized ? "active" : "pending"
            try data.write(to: directory.appendingPathComponent("settings-\(language.rawValue)-\(appearance)-\(state).png"))
           }
          }
        }
    }
}
