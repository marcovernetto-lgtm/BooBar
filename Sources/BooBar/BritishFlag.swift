import SwiftUI

// Monochrome Union Jack: the wider diagonal bands sit behind the central cross.
struct BritishFlag: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.clip(to: Path(roundedRect: bounds, cornerRadius: 2))
            var diagonals = Path()
            diagonals.move(to: .zero)
            diagonals.addLine(to: CGPoint(x: size.width, y: size.height))
            diagonals.move(to: CGPoint(x: 0, y: size.height))
            diagonals.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(diagonals, with: .foreground, lineWidth: size.height * 0.19)
            var cross = Path()
            cross.addRect(CGRect(x: size.width * 0.39, y: 0, width: size.width * 0.22, height: size.height))
            cross.addRect(CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.30))
            context.fill(cross, with: .foreground)
            context.stroke(Path(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2),
                           with: .foreground, lineWidth: 1)
        }
    }
}
