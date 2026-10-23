import AppKit
import ApplicationServices

struct MenuBarApp: Sendable {
    let pid: pid_t
    let bundleID: String
}

enum MenuBarReader {
    static func read(_ apps: [MenuBarApp], on screen: CGRect) throws -> [PositionedIcon] {
        let deadline = Date().addingTimeInterval(3)
        var icons: [PositionedIcon] = []
        for app in apps {
            guard Date() < deadline else { throw LayoutError.incompleteScan }
            let element = AXUIElementCreateApplication(app.pid)
            AXUIElementSetMessagingTimeout(element, 0.04)
            guard let value = attribute(element, kAXExtrasMenuBarAttribute),
                  CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
            let bar = value as! AXUIElement
            guard let children = attribute(bar, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            for child in children {
                guard Date() < deadline else { throw LayoutError.incompleteScan }
                guard let position = attribute(child, kAXPositionAttribute),
                      let size = attribute(child, kAXSizeAttribute),
                      CFGetTypeID(position) == AXValueGetTypeID(),
                      CFGetTypeID(size) == AXValueGetTypeID() else { continue }
                var origin = CGPoint.zero
                var extent = CGSize.zero
                guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
                      AXValueGetValue(size as! AXValue, .cgSize, &extent),
                      extent.width > 1, extent.height > 1, extent.height < 80,
                      screen.contains(CGPoint(x: origin.x + extent.width/2, y: origin.y + extent.height/2)) else { continue }
                icons.append(PositionedIcon(bundleID: app.bundleID, x: origin.x + extent.width/2))
            }
        }
        return icons
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
