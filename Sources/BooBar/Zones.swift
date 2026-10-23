import Foundation

enum Zone: String, Codable, Sendable {
    case visible, temporary, alwaysHidden
}

enum BarMode: Equatable {
    case collapsed, expanded, arranging, suspended
    var showsSecondWall: Bool { self == .expanded || self == .arranging }
}

struct PositionedIcon: Sendable {
    let bundleID: String
    let x: Double
}

struct Zones: Codable {
    var assignments: [String: Zone] = [:]
    var suspended = false

    func hidden(in mode: BarMode) -> Set<String> {
        guard mode == .collapsed || mode == .expanded else { return [] }
        return Set(assignments.compactMap { id, zone in
            if zone == .alwaysHidden || (zone == .temporary && mode == .collapsed) { return id }
            return nil
        })
    }

    mutating func arrange(_ icons: [PositionedIcon], permanentWall: Double, mainWall: Double) throws {
        guard permanentWall.isFinite, mainWall.isFinite, permanentWall < mainWall else {
            throw LayoutError.reversedWalls
        }
        var updated = assignments
        for (id, group) in Dictionary(grouping: icons.filter { $0.x.isFinite }, by: \.bundleID) {
            let zone: Zone
            if group.contains(where: { $0.x > mainWall }) { zone = .visible }
            else if group.contains(where: { $0.x > permanentWall }) { zone = .temporary }
            else { zone = .alwaysHidden }
            updated[id] = zone
        }
        assignments = updated
        suspended = false
    }

    mutating func reset() {
        assignments.removeAll()
        suspended = true
    }
}

enum LayoutError: LocalizedError {
    case reversedWalls, incompleteScan
    var message: BooText { self == .reversedWalls ? .reversedWalls : .incompleteScan }
    var errorDescription: String? { AppLanguage.load().text(message) }
}
