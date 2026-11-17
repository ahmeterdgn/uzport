import AppKit
import SwiftUI
import PortCore

enum Theme {
    static let bg = Color(hex: 0x0E1118)
    static let card = Color(hex: 0x1A2130)
    static let stroke = Color.white.opacity(0.07)
    static let strokeHi = Color.white.opacity(0.13)
    static let text = Color(hex: 0xE9EDF5)
    static let text2 = Color(hex: 0x9AA4B6)
    static let text3 = Color(hex: 0x5F6A7E)
    static let accent = Color(hex: 0x5B8CFF)
    static let accent2 = Color(hex: 0x9A6BFF)
    static let green = Color(hex: 0x34D399)
    static let amber = Color(hex: 0xFBBF24)
    static let red = Color(hex: 0xF87171)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

struct NightSky: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: .topTrailing, startRadius: 4, endRadius: 360)
            RadialGradient(colors: [Theme.accent2.opacity(0.10), .clear], center: .bottomLeading, startRadius: 4, endRadius: 320)
            Canvas { ctx, size in
                var seed: UInt64 = 0x2545F4914F6CDD1D
                func rnd() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 11) / Double(1 << 53)
                }
                for _ in 0..<70 {
                    let r = 0.4 + rnd() * 1.0
                    ctx.fill(Path(ellipseIn: CGRect(x: rnd() * size.width, y: rnd() * size.height, width: r, height: r)),
                             with: .color(.white.opacity(0.05 + rnd() * 0.2)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct Chip: View {
    let text: String
    var symbol: String? = nil
    var color: Color = Theme.text2

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 8.5, weight: .bold)) }
            Text(text).font(.system(size: 10.5, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(color.opacity(0.13)))
        .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.8))
        .fixedSize()
    }
}

struct IconButton: View {
    let symbol: String
    var tint: Color = Theme.text2
    var help: String = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(hover ? Theme.text : tint)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hover ? Color.white.opacity(0.09) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct AppLogo: View {
    var size: CGFloat = 22
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size * 1.24, height: size * 1.24)
            .frame(width: size, height: size)
    }
}

struct UzmoonCredit: View {
    var body: some View {
        Link(destination: URL(string: "https://uzmoon.com/")!) {
            HStack(spacing: 6) {
                if let url = Bundle.main.url(forResource: "uzmoon", withExtension: "png"), let img = NSImage(contentsOf: url) {
                    Image(nsImage: img).resizable().frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                }
                Text(L("uzmoon.com tarafından yapılmıştır", "Made by uzmoon.com")).font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(Theme.text3)
        }
        .buttonStyle(.plain)
    }
}
