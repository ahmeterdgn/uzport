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
        if let dir = env["UZPORT_SELFTEST"] { await selfTest(dir); return }
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
        if env["UZPORT_DEMO_LOGS"] != nil, let m = ProcessManager.shared.servers.first {
            root = AnyView(LogView(server: m).environmentObject(ProcessManager.shared).frame(width: 820, height: 440))
        } else if env["UZPORT_DEMO_QR"] != nil, let it = store.items.first(where: { $0.port == 5173 }) {
            root = AnyView(QRCard(item: it).environmentObject(store).environmentObject(ProcessManager.shared).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.dark))
        } else {
            root = AnyView(PanelView().environmentObject(store).environmentObject(ProcessManager.shared))
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

    /// Uçtan uca: projeyi başlat → port açılsın ve sunucuya bağlansın → durdur → port kapansın.
    static func selfTest(_ dir: String) async {
        func say(_ s: String) { print(s); fflush(stdout) }
        guard let project = ProjectScanner.project(at: dir) else { say("FAIL proje bulunamadı"); exit(1) }
        say("proje: \(project.name) → \(project.defaultCommand?.command ?? "-")")
        let pm = ProcessManager.shared
        let store = PortStore.shared
        guard let s = pm.start(project) else { say("FAIL başlatılamadı"); exit(1) }
        var linked: PortItem?
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            store.refresh()
            if let it = store.items.first(where: { $0.managedID == s.id }) { linked = it; break }
        }
        guard let it = linked else { say("FAIL port bağlanmadı; log:\n" + s.lines.suffix(10).joined(separator: "\n")); exit(1) }
        say("OK port :\(it.port) açıldı, pid \(it.pid) (kabuk \(s.pid)) yönetilen sunucuya bağlandı, durum \(s.state)")
        let port = it.port
        pm.stop(s)
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if !PortScanner.scan().contains(where: { $0.port == port }) && !s.state.isAlive {
                say("OK durduruldu, port :\(port) kapandı, durum \(s.state)")
                say("log son satırlar: " + s.lines.suffix(3).joined(separator: " | "))
                exit(0)
            }
        }
        say("FAIL port kapanmadı")
        exit(1)
    }

    static func loadDemoData(into store: PortStore) {
        let home = "/Users/demo" // gizlilik: gerçek kullanıcı adı görünmez
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

        // Başlatılabilir örnek projeler ve UzPort'un başlattığı bir sunucu.
        let pm = ProcessManager.shared
        let base = home + "/Projects/"
        pm.projects = [
            Project(name: "moon-landing", path: base + "moon-landing", kindName: "Vite",
                    commands: [RunCommand(label: "dev", command: "pnpm run dev")]),
            Project(name: "blog", path: base + "blog", kindName: "Astro",
                    commands: [RunCommand(label: "dev", command: "npm run dev"), RunCommand(label: "preview", command: "npm run preview")]),
            Project(name: "admin-panel", path: base + "admin-panel", kindName: "Next.js",
                    commands: [RunCommand(label: "dev", command: "npm run dev")]),
            Project(name: "infra", path: base + "infra", kindName: "Docker Compose",
                    commands: [RunCommand(label: "compose", command: "docker compose up")]),
        ]
        pm.recent = [base + "blog", base + "admin-panel", base + "infra"]
        let m = ManagedServer(project: pm.projects[0], command: pm.projects[0].commands[0])
        m.state = .running
        m.pid = 41200
        m.detectedURL = URL(string: "http://localhost:5173/")
        m.lines = [
            "$ pnpm run dev", "  " + base + "moon-landing", "",
            "> moon-landing@0.4.2 dev " + base + "moon-landing", "> vite", "",
            "  VITE v5.4.10  ready in 412 ms", "",
            "  ➜  Local:   http://localhost:5173/", "  ➜  Network: http://192.168.1.20:5173/", "  ➜  press h + enter to show help",
            "05:12:03 [vite] page reload src/App.tsx",
            "05:12:41 [vite] hmr update /src/components/Hero.tsx, /src/index.css",
            "05:13:02 [vite] warning: src/components/Stars.tsx: 'useMemo' is defined but never used",
            "05:13:19 [vite] hmr update /src/components/Hero.tsx",
        ]
        pm.servers = [m]
        if let i = store.items.firstIndex(where: { $0.port == 5173 }) { store.items[i].managedID = m.id }
    }
}
