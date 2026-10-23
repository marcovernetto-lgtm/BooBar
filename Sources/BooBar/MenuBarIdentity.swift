import AppKit
import Security

struct MenuBarIdentity {
    let bundleID: String
    let signingID: String?

    static func read(_ app: NSRunningApplication) -> MenuBarIdentity? {
        guard let bundleID = app.bundleIdentifier else { return nil }
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        let attributes = [kSecGuestAttributePid: app.processIdentifier] as CFDictionary
        if SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code,
           SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode {
            SecCodeCopySigningInformation(staticCode, [], &information)
        }
        let signingID = (information as? [String: Any])?[kSecCodeInfoIdentifier as String] as? String
        return MenuBarIdentity(bundleID: bundleID, signingID: signingID)
    }

    static func allowed(_ apps: [MenuBarIdentity], hiding hidden: Set<String>) -> Set<String> {
        var allowed = Set<String>()
        for app in apps where !hidden.contains(app.bundleID) {
            allowed.insert(app.bundleID)
            // Local builds can have a signing identifier different from Info.plist.
            if let signingID = app.signingID { allowed.insert(signingID) }
        }
        return allowed
    }
}
