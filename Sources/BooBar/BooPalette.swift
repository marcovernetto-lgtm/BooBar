import SwiftUI

extension Color {
    init(boobarHex hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

enum BooPalette {
    static let background = Color(boobarHex: 0x0e171b)
    static let panel = Color(boobarHex: 0x253136)
    static let text = Color(boobarHex: 0xedf3f3)
    static let muted = Color(boobarHex: 0xa4b5b8)
    static let accent = Color(boobarHex: 0xa4dcd5)
    static let primary = Color(boobarHex: 0x287c83)
    static let border = Color(boobarHex: 0xdff0eb).opacity(0.14)
    static func font(_ size: CGFloat, strong: Bool = false) -> Font {
        .custom(strong ? "AvenirNext-DemiBold" : "AvenirNext-Regular", size: size)
    }
}

struct BooButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BooPalette.font(12, strong: true))
            .foregroundStyle(BooPalette.text)
            .padding(.horizontal, 14).frame(minHeight: 36)
            .background(primary ? BooPalette.primary : BooPalette.accent.opacity(hovering ? 0.13 : 0.055),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BooPalette.border, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
