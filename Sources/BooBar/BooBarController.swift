import AppKit
import ApplicationServices
import SwiftUI
import MenuBarBridge
import ServiceManagement
import os

@MainActor
final class BooBarController: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    @Published private(set) var loginItemStatus = SMAppService.mainApp.status
    @Published private(set) var loginItemError: String?
    var launchesAtLogin: Bool { loginItemStatus == .enabled || loginItemStatus == .requiresApproval }

    @Published private(set) var settingsVisible = false
    @Published var authorized = AXIsProcessTrusted()
    @Published var language = AppLanguage.load() {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "BooBar.language")
            updateMenuLanguage()
        }
    }
    @Published private(set) var problem: BooText?
    private var mode = BarMode.suspended
    let nativeAvailable = HBMenuBar.available

    private let engine = HBMenuBar()
    private let log = Logger(subsystem: "it.marcovernetto.BooBar", category: "MenuBar")
    private var zones = Zones()
    private var mainWall: NSStatusItem!
    private var alwaysWall: NSStatusItem!
    private var settings: NSWindow?
    private var timer: Timer?
    private var lastGesture = Date.distantPast
    private var lastMenuPresence = Date()
    private var hoverStart: Date?
    private var permissionCheck = Date.distantPast
    private var scanning = false
    private var revision = 0
    private var operation = 0
    private var pendingOperation: Int?
    private var currentAllowed: Set<String>?
    private var identities: [MenuBarIdentity]?
    private let storageKey = "Hidebar.zones.v3"

    init(language: AppLanguage = .load()) {
        self.language = language
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let saved = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Zones.self, from: saved) { zones = decoded }
        mainWall = wall(":", autosave: "HidebarMainWall", action: #selector(mainClicked))
        alwaysWall = wall("|", autosave: "HidebarPermanentWall", action: #selector(alwaysClicked))
        alwaysWall.isVisible = false
        updateMenuLanguage()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationsChanged),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationsChanged),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        mode = zones.suspended || zones.assignments.isEmpty ? .suspended : .collapsed
        apply()
        if !UserDefaults.standard.bool(forKey: "BooBar.didShowWelcome") || !authorized {
            showSettings()
            UserDefaults.standard.set(true, forKey: "BooBar.didShowWelcome")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 0.05
        if !authorized {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.requestPermission() }
        }
        log.notice("Avvio BooBar: Accessibility=\(self.authorized), nativeAPI=\(self.nativeAvailable), impostazioni=\(self.settingsVisible), login=\(self.loginItemStatus.rawValue)")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermission()
        refreshLoginItem()
    }
    func applicationWillTerminate(_ notification: Notification) { engine.restore() }

    private func wall(_ title: String, autosave: String, action: Selector) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: 22)
        item.autosaveName = autosave
        item.isVisible = true
        item.button?.title = title
        item.button?.font = .monospacedSystemFont(ofSize: 16, weight: title == ":" ? .semibold : .regular)
        item.button?.target = self
        item.button?.action = action
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = language.text(title == ":" ? .mainTip : .permanentTip)
        item.button?.setAccessibilityLabel(title == ":" ? "BooBar" : language.text(.permanentWall))
        return item
    }

    private func updateMenuLanguage() {
        let menu = NSMenu()
        let application = NSMenuItem()
        let actions = NSMenu()
        actions.addItem(withTitle: language.text(.settings) + "…", action: #selector(showSettings), keyEquivalent: ",").target = self
        actions.addItem(withTitle: language.text(.quit), action: #selector(quit), keyEquivalent: "q").target = self
        application.submenu = actions
        menu.addItem(application)
        NSApp.mainMenu = menu
        mainWall?.button?.toolTip = language.text(.mainTip)
        alwaysWall?.button?.toolTip = language.text(.permanentTip)
        alwaysWall?.button?.setAccessibilityLabel(language.text(.permanentWall))
    }

    @objc func showSettings() {
        refreshPermission()
        refreshLoginItem()
        if settings == nil {
            let host = NSHostingController(rootView: SettingsView(controller: self))
            host.sizingOptions = [.minSize, .intrinsicContentSize, .maxSize, .preferredContentSize]
            let window = NSWindow(contentViewController: host)
            window.title = "BooBar"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(srgbRed: 14/255, green: 23/255, blue: 27/255, alpha: 1)
            window.appearance = NSAppearance(named: .darkAqua)
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(host.view.fittingSize)
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
        settingsVisible = true
    }

    func refreshLoginItem() {
        let status = SMAppService.mainApp.status
        if status != loginItemStatus { loginItemError = nil }
        loginItemStatus = status
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        loginItemError = nil
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
        }
        refreshLoginItem()
        if enabled && loginItemStatus == .requiresApproval { openLoginSettings() }
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func windowWillClose(_ notification: Notification) { settingsVisible = false }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        settingsVisible = settings?.occlusionState.contains(.visible) == true
    }

    @objc func requestPermission() {
        guard !authorized else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshPermission() {
        let granted = AXIsProcessTrusted()
        guard granted != authorized else { return }
        authorized = granted
        revision += 1
        problem = nil
        if granted { apply() }
        else { revealEverything(); mode = .suspended; alwaysWall?.isVisible = false }
        log.notice("Permesso Accessibility aggiornato: \(granted)")
    }

    func restart() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.5; exec /usr/bin/open -a \"$1\"", "BooBar", Bundle.main.bundleURL.path]
        do { try process.run(); NSApp.terminate(nil) }
        catch { problem = .restartFailure }
    }

    @objc private func mainClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings(); return }
        guard authorized else { showSettings(); return }
        transition(mode == .collapsed ? .expanded : .collapsed)
    }

    @objc private func alwaysClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showSettings() }
        else { beginArrangement() }
    }

    @objc func reset() {
        revision += 1
        zones.reset()
        save()
        problem = nil
        transition(.suspended)
    }

    @objc func quit() { NSApp.terminate(nil) }

    private func beginArrangement() {
        guard authorized, nativeAvailable else { return }
        if mode != .arranging { revision += 1; transition(.arranging) }
        lastGesture = Date()
        problem = nil
    }

    private func transition(_ newMode: BarMode) {
        mode = newMode
        lastMenuPresence = Date()
        alwaysWall.isVisible = newMode.showsSecondWall && authorized
        apply()
    }

    private func tick() {
        if Date().timeIntervalSince(permissionCheck) > 1 {
            permissionCheck = Date()
            refreshPermission()
        }
        guard authorized, nativeAvailable, let wallFrame = frame(mainWall) else { return }
        let flags = NSEvent.modifierFlags
        let moving = flags.contains(.command) && (flags.contains(.shift) || NSEvent.pressedMouseButtons != 0)
        if moving { beginArrangement(); return }
        if mode == .arranging {
            if NSEvent.pressedMouseButtons == 0 && Date().timeIntervalSince(lastGesture) > 0.6 { commitPositions() }
            return
        }
        let pointer = NSEvent.mouseLocation
        if wallFrame.insetBy(dx: -4, dy: 0).contains(pointer), mode == .collapsed {
            if let start = hoverStart, Date().timeIntervalSince(start) > 0.18 { transition(.expanded) }
            else if hoverStart == nil { hoverStart = Date() }
        } else { hoverStart = nil }
        if mode == .expanded {
            let inMenuBar = NSScreen.screens.contains {
                $0.frame.minX <= pointer.x && pointer.x <= $0.frame.maxX &&
                $0.frame.maxY - NSStatusBar.system.thickness - 3 <= pointer.y && pointer.y <= $0.frame.maxY
            }
            if inMenuBar || NSEvent.pressedMouseButtons != 0 || menuIsOpen() { lastMenuPresence = Date() }
            else if Date().timeIntervalSince(lastMenuPresence) > 1.2 { transition(.collapsed) }
        }
    }

    private func commitPositions() {
        guard !scanning, let main = frame(mainWall), let permanent = frame(alwaysWall),
              let screen = mainWall.button?.window?.screen else { return }
        guard permanent.midX < main.midX else { fail(.reversedWalls); return }
        let ignored = Set([Bundle.main.bundleIdentifier ?? "", "com.apple.controlcenter",
                           "com.apple.systemuiserver", "com.apple.MenuBarAgent"])
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> MenuBarApp? in
            guard let id = app.bundleIdentifier, !ignored.contains(id), !app.isTerminated else { return nil }
            return MenuBarApp(pid: app.processIdentifier, bundleID: id)
        }
        let top = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let bounds = CGRect(x: screen.frame.minX, y: top - screen.frame.maxY,
                            width: screen.frame.width, height: screen.frame.height)
        let capturedRevision = revision
        let gestureTime = lastGesture
        scanning = true
        Task {
            defer { scanning = false }
            do {
                let icons = try await Task.detached { try MenuBarReader.read(apps, on: bounds) }.value
                guard capturedRevision == revision, gestureTime == lastGesture, mode == .arranging,
                      authorized, !NSEvent.modifierFlags.contains(.command), NSEvent.pressedMouseButtons == 0 else { return }
                try zones.arrange(icons, permanentWall: permanent.midX, mainWall: main.midX)
                save()
                transition(.expanded)
                log.notice("Ordinamento salvato: \(icons.count) icone lette, \(self.zones.assignments.count) app")
            } catch {
                guard capturedRevision == revision, gestureTime == lastGesture, mode == .arranging else { return }
                fail((error as? LayoutError)?.message ?? .nativeFailure)
            }
        }
    }

    private func apply() {
        let hidden = zones.hidden(in: mode)
        guard authorized, nativeAvailable, !hidden.isEmpty else { revealEverything(); return }
        // Signing metadata is stable for a running process; refresh only when apps change.
        if identities == nil { identities = NSWorkspace.shared.runningApplications.compactMap(MenuBarIdentity.read) }
        var allowed = MenuBarIdentity.allowed(identities ?? [], hiding: hidden)
        allowed.insert(Bundle.main.bundleIdentifier ?? "it.marcovernetto.Hidebar")
        guard allowed != currentAllowed else { return }
        currentAllowed = allowed
        operation += 1
        let token = operation
        pendingOperation = token
        engine.allowBundles(allowed.sorted()) { [weak self] error in
            Task { @MainActor in
                guard let self, token == self.operation else { return }
                self.pendingOperation = nil
                if let error {
                    self.log.error("Native visibility failed: \(error.localizedDescription, privacy: .public)")
                    self.fail(.nativeFailure)
                }
                else { self.log.notice("Nascondimento nativo attivo: \(hidden.count) app") }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, token == self.operation, self.pendingOperation == token else { return }
            self.fail(.nativeFailure)
        }
    }

    private func revealEverything() {
        operation += 1
        pendingOperation = nil
        currentAllowed = nil
        engine.restore()
    }

    private func fail(_ message: BooText) {
        revealEverything()
        mode = .suspended
        alwaysWall.isVisible = false
        problem = message
        log.error("\(message.rawValue, privacy: .public)")
    }

    @objc private func applicationsChanged() {
        identities = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.identities = nil
            self?.apply()
        }
    }

    private func frame(_ item: NSStatusItem?) -> CGRect? {
        guard let button = item?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func menuIsOpen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(zones) { UserDefaults.standard.set(encoded, forKey: storageKey) }
    }
}
