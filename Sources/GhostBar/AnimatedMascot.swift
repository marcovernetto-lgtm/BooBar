import SwiftUI

struct MascotPose: Equatable {
    var leftHand: CGFloat = 0
    var rightHand: CGFloat = 0
    var gaze: CGFloat = 0.4
    var leftBlink: CGFloat = 0
    var rightBlink: CGFloat = 0
    var breath: CGFloat = 0
    static let duration = 6.4
    static let resting = MascotPose()

    static func at(_ elapsed: TimeInterval, reducedMotion: Bool = false) -> MascotPose {
        guard !reducedMotion else { return .resting }
        let t = (elapsed.truncatingRemainder(dividingBy: duration) + duration)
            .truncatingRemainder(dividingBy: duration)
        func sample(_ keys: [(Double, Double)]) -> CGFloat {
            for (a, b) in zip(keys, keys.dropFirst()) where t <= b.0 {
                let p = max(0, min(1, (t - a.0) / (b.0 - a.0)))
                let s = p * p * (3 - 2 * p)
                return a.1 + (b.1 - a.1) * s
            }
            return keys.last?.1 ?? 0
        }
        return MascotPose(
            leftHand: sample([(0,0),(1,0),(1.65,1),(2.25,1),(2.85,0.18),(3.15,0.18),(3.75,0),(6.4,0)]),
            rightHand: sample([(0,0),(1.3,0),(1.95,1),(2.65,1),(3.3,0.35),(3.85,0),(6.4,0)]),
            gaze: sample([(0,0.4),(0.9,-0.65),(1.5,-0.65),(2.85,0.8),(3.8,0.8),(4.5,-0.5),(5.4,0.4),(6.4,0.4)]),
            leftBlink: sample([(0,0),(0.5,0),(0.61,0.96),(0.75,0),(4.6,0),(4.73,0.96),(4.88,0),(6.4,0)]),
            rightBlink: sample([(0,0),(0.54,0),(0.65,0.96),(0.79,0),(4.7,0),(4.83,0.96),(4.98,0),(6.4,0)]),
            breath: 0.8 * (1 - cos(t / duration * .pi * 2)))
    }
}

struct MascotLayer {
    let name: String
    let path: Path
    let color: UInt32
    var stroke: CGFloat = 0
}

// The same paths feed the native animation and the layered SVG export.
enum BooVector {
    static let cream: UInt32 = 0xedf3f3
    static let ink: UInt32 = 0x0e171b
    static let ghostFill: UInt32 = 0x18262b
    static let ghostStroke: UInt32 = 0x287c83

    static let letter: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 104, y: 102))
        p.addCurve(to: CGPoint(x: 200, y: 18), control1: CGPoint(x: 104, y: 46), control2: CGPoint(x: 144, y: 18))
        p.addCurve(to: CGPoint(x: 296, y: 102), control1: CGPoint(x: 256, y: 18), control2: CGPoint(x: 296, y: 46))
        p.addLine(to: CGPoint(x: 296, y: 166))
        p.addQuadCurve(to: CGPoint(x: 264, y: 156), control: CGPoint(x: 280, y: 174))
        p.addQuadCurve(to: CGPoint(x: 232, y: 166), control: CGPoint(x: 248, y: 146))
        p.addQuadCurve(to: CGPoint(x: 200, y: 156), control: CGPoint(x: 216, y: 174))
        p.addQuadCurve(to: CGPoint(x: 168, y: 166), control: CGPoint(x: 184, y: 146))
        p.addQuadCurve(to: CGPoint(x: 136, y: 156), control: CGPoint(x: 152, y: 174))
        p.addQuadCurve(to: CGPoint(x: 104, y: 166), control: CGPoint(x: 120, y: 146))
        p.closeSubpath()
        return p
    }()

    static let palm: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -22, y: 24))
        p.addCurve(to: CGPoint(x: -18, y: -15), control1: CGPoint(x: -31, y: 5), control2: CGPoint(x: -29, y: -9))
        p.addCurve(to: CGPoint(x: 0, y: -20), control1: CGPoint(x: -23, y: -35), control2: CGPoint(x: -3, y: -39))
        p.addCurve(to: CGPoint(x: 16, y: -18), control1: CGPoint(x: 3, y: -42), control2: CGPoint(x: 25, y: -37))
        p.addCurve(to: CGPoint(x: 28, y: -3), control1: CGPoint(x: 27, y: -32), control2: CGPoint(x: 41, y: -18))
        p.addCurve(to: CGPoint(x: 29, y: 18), control1: CGPoint(x: 44, y: -5), control2: CGPoint(x: 43, y: 11))
        p.addCurve(to: CGPoint(x: -22, y: 24), control1: CGPoint(x: 25, y: 45), control2: CGPoint(x: -11, y: 43))
        p.closeSubpath()
        return p
    }()

    static func layers(for pose: MascotPose) -> [MascotLayer] {
        let breath = CGAffineTransform(translationX: 0, y: -pose.breath)
        var result = [
            MascotLayer(name: "ghost-body", path: letter.applying(breath), color: ghostFill),
            MascotLayer(name: "ghost-outline", path: letter.applying(breath), color: ghostStroke, stroke: 3)
        ]
        for (name, x, blink) in [("left", CGFloat(162), pose.leftBlink), ("right", CGFloat(238), pose.rightBlink)] {
            let height = 74 * (1 - blink)
            let eye = CGRect(x: x - 35, y: 98 - height / 2 - pose.breath, width: 70, height: height)
            result.append(MascotLayer(name: name + "-eye", path: Path(ellipseIn: eye), color: cream))
            if blink < 0.5 {
                let px = x + pose.gaze * 9
                result.append(MascotLayer(name: name + "-pupil", path: Path(ellipseIn:
                    CGRect(x: px - 16, y: 80 - pose.breath, width: 32, height: 35)), color: ink))
                result.append(MascotLayer(name: name + "-glint", path: Path(ellipseIn:
                    CGRect(x: px + 3, y: 84 - pose.breath, width: 8, height: 8)), color: cream))
            }
        }
        var smile = Path()
        smile.move(to: CGPoint(x: 189, y: 142 - pose.breath))
        smile.addQuadCurve(to: CGPoint(x: 211, y: 142 - pose.breath), control: CGPoint(x: 200, y: 156 - pose.breath))
        result.append(MascotLayer(name: "smile", path: smile, color: cream, stroke: 4))
        for (name, progress, side) in [("left", pose.leftHand, CGFloat(1)), ("right", pose.rightHand, CGFloat(-1))] {
            let x = side == 1 ? 81 + progress * 76 : 319 - progress * 76
            let y = 144 - progress * 48 - pose.breath
            let angle = side * (-0.22 + progress * 0.32)
            let transform = CGAffineTransform(a: side * cos(angle), b: side * sin(angle),
                c: -sin(angle), d: cos(angle), tx: x, ty: y)
            let shape = palm.applying(transform)
            result.append(MascotLayer(name: name + "-hand", path: shape, color: cream))
            result.append(MascotLayer(name: name + "-hand-outline", path: shape, color: ink, stroke: 2.5))
            var fingers = Path()
            fingers.move(to: CGPoint(x: -17, y: 2))
            fingers.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: -1, y: -5))
            fingers.move(to: CGPoint(x: -15, y: 13))
            fingers.addQuadCurve(to: CGPoint(x: 17, y: 14), control: CGPoint(x: 0, y: 8))
            result.append(MascotLayer(name: name + "-fingers", path: fingers.applying(transform), color: ink, stroke: 2))
        }
        return result
    }
}

struct MascotFrame: View {
    let pose: MascotPose
    var width: CGFloat = 300
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 400, size.height / 190)
            context.translateBy(x: (size.width - 400 * scale) / 2, y: (size.height - 190 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            for layer in BooVector.layers(for: pose) {
                if layer.stroke > 0 {
                    context.stroke(layer.path, with: .color(Color(boobarHex: layer.color)),
                        style: StrokeStyle(lineWidth: layer.stroke, lineCap: .round, lineJoin: .round))
                } else {
                    context.fill(layer.path, with: .color(Color(boobarHex: layer.color)), style: FillStyle(eoFill: true))
                }
            }
        }
        .frame(width: width, height: width * 145 / 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ghosty")
    }
}

struct AnimatedMascot: View {
    let active: Bool
    var width: CGFloat = 300
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { context in
            MascotFrame(pose: active ? .at(context.date.timeIntervalSince(started), reducedMotion: reduceMotion) : .resting, width: width)
        }
        .onChange(of: active) { _, visible in if visible { started = Date() } }
    }
}
