import AppKit
import SwiftUI
import PortCore

/// README görselleri için: paneli bağımsız bir pencerede çizip PNG olarak kaydeder.
/// Yalnızca UZPORT_SCREENSHOT ayarlıysa çalışır. UZPORT_DEMO_DATA=1 iken bu Mac'in gerçek portları yerine
/// örnek veri gösterilir (gizlilik: ekran görüntülerinde kişisel süreç/ağ bilgisi olmaz).
@MainActor
enum DemoMode {
    static var window: NSWindow?

    static var isDemoData: Bool { ProcessInfo.processInfo.environment["UZPORT_DEMO_DATA"] != nil }

    static func runIfRequested() async {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["UZPORT_SCREENSHOT"] else { return }
        let store = PortStore.shared
        if isDemoData {
            loadDemoData(into: store)
        } else {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // tarama + HTTP yoklamaları
        }
        if let q = env["UZPORT_DEMO_QUERY"] { store.query = q }
        try? await Task.sleep(nanoseconds: 400_000_000)

        let root: AnyView
        if env["UZPORT_DEMO_QR"] != nil, let it = store.items.first(where: { $0.port == 5173 }) {
            root = AnyView(QRCard(item: it).environmentObject(store).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.dark))
        } else {
            root = AnyView(PanelView().environmentObject(store))
        }
        let host = NSHostingView(rootView: root)
        host.frame.size = host.fittingSize
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.isOpaque = false
        w.backgroundColor = .clear
        w.orderFrontRegardless()
        window = w
        try? await Task.sleep(nanoseconds: 800_000_000)
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
        }
        NSApp.terminate(nil)
    }

    static func loadDemoData(into store: PortStore) {
        let home = NSHomeDirectory()
        func item(_ port: UInt16, pid: pid_t, name: String, cat: PortCategory, kind: ServerKind, project: String? = nil,
                  minutesAgo: Double, mem: UInt64, loopback: Bool = true, docker: (String, String)? = nil) -> PortItem {
            let d = ProcessDetails(pid: pid, name: name, path: "/opt/homebrew/bin/\(name)", arguments: [name],
                                   cwd: nil, startDate: Date().addingTimeInterval(-minutesAgo * 60),
                                   residentBytes: mem, uid: getuid(), parentPID: 1)
            let s = ListeningSocket(pid: pid, port: port, address: loopback ? "127.0.0.1" : "*", isIPv6: false)
            var it = PortItem(socket: s, details: d,
                              cls: Classification(category: cat, kind: kind, projectName: project,
                                                  projectPath: project.map { home + "/Projects/" + $0 }))
            if let docker { it.dockerName = docker.0; it.dockerImage = docker.1 }
            return it
        }
        store.items = [
            item(5173, pid: 41210, name: "node", cat: .dev, kind: ServerKind("Vite", "bolt.fill", 0x9A6BFF),
                 project: "moon-landing", minutesAgo: 12, mem: 182_000_000, loopback: false),
            item(3000, pid: 41388, name: "node", cat: .dev, kind: ServerKind("Next.js", "n.square.fill", 0xE5E7EB),
                 project: "dashboard", minutesAgo: 47, mem: 412_000_000),
            item(8000, pid: 40912, name: "php", cat: .dev, kind: ServerKind("Laravel", "flame.fill", 0xF05340),
                 project: "shop-api", minutesAgo: 95, mem: 38_000_000),
            item(6006, pid: 41602, name: "node", cat: .dev, kind: ServerKind("Storybook", "book.fill", 0xFF4785),
                 project: "ui-kit", minutesAgo: 3, mem: 260_000_000),
            item(5432, pid: 812, name: "postgres", cat: .services, kind: ServerKind("PostgreSQL", "cylinder.split.1x2.fill", 0x336791, browser: false),
                 minutesAgo: 60 * 26, mem: 21_000_000),
            item(6379, pid: 815, name: "redis-server", cat: .services, kind: ServerKind("Redis", "square.stack.3d.up.fill", 0xDC382D, browser: false),
                 minutesAgo: 60 * 26, mem: 9_000_000),
            item(11434, pid: 902, name: "ollama", cat: .services, kind: ServerKind("Ollama", "brain.head.profile", 0xE5E7EB),
                 minutesAgo: 60 * 9, mem: 22_000_000),
            item(8080, pid: 3101, name: "limactl", cat: .docker, kind: ServerKind("Docker", "shippingbox.fill", 0x2496ED),
                 minutesAgo: 200, mem: 27_000_000, docker: ("web", "nginx:alpine")),
            item(8025, pid: 3101, name: "limactl", cat: .docker, kind: ServerKind("Docker", "shippingbox.fill", 0x2496ED),
                 minutesAgo: 200, mem: 27_000_000, docker: ("mailpit", "axllent/mailpit")),
        ]
        func fav(_ symbol: String, _ color: NSColor) -> NSImage? {
            let cfg = NSImage.SymbolConfiguration(pointSize: 40, weight: .bold).applying(.init(paletteColors: [color]))
            return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        }
        store.probes = [
            "41210:5173": ProbeResult(status: 200, pageTitle: "Moon Landing — Vite + React", favicon: fav("bolt.fill", .systemPurple)),
            "41388:3000": ProbeResult(status: 200, pageTitle: L("Kontrol Paneli", "Dashboard"), favicon: nil),
            "40912:8000": ProbeResult(status: 200, pageTitle: "Shop API", favicon: fav("flame.fill", .systemRed)),
            "41602:6006": ProbeResult(status: 200, pageTitle: "Storybook", favicon: nil),
            "902:11434": ProbeResult(status: 200, pageTitle: nil, favicon: nil),
            "3101:8080": ProbeResult(status: 200, pageTitle: "Welcome to nginx!", favicon: nil),
            "3101:8025": ProbeResult(status: 200, pageTitle: "Mailpit", favicon: fav("envelope.fill", .systemBlue)),
        ]
        store.lan = "192.168.1.20"
    }
}
