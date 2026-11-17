import Foundation

public enum PortCategory: String, CaseIterable, Sendable, Codable {
    case dev, services, docker, apps, system

    public var title: String {
        switch self {
        case .dev: return L("Projelerin", "Your projects")
        case .services: return L("Veritabanları ve servisler", "Databases & services")
        case .docker: return L("Docker", "Docker")
        case .apps: return L("Uygulamalar", "Apps")
        case .system: return L("macOS sistemi", "macOS system")
        }
    }
}

/// Sunucunun türü (Vite, Laravel, PostgreSQL…).
public struct ServerKind: Hashable, Sendable {
    public let name: String
    public let symbol: String
    public let color: UInt32
    public let opensInBrowser: Bool

    public init(_ name: String, _ symbol: String, _ color: UInt32, browser: Bool = true) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.opensInBrowser = browser
    }
}

public struct Classification: Hashable, Sendable {
    public var category: PortCategory
    public var kind: ServerKind
    public var projectName: String?
    public var projectPath: String?

    public init(category: PortCategory, kind: ServerKind, projectName: String? = nil, projectPath: String? = nil) {
        self.category = category
        self.kind = kind
        self.projectName = projectName
        self.projectPath = projectPath
    }
}

public enum Classifier {
    static let home = NSHomeDirectory()

    // (anahtar kelime, tür) — komut satırında ilk eşleşen kazanır.
    static let devRules: [(String, ServerKind)] = [
        ("vite", ServerKind("Vite", "bolt.fill", 0x9A6BFF)),
        ("next dev", ServerKind("Next.js", "n.square.fill", 0xE5E7EB)),
        ("next-server", ServerKind("Next.js", "n.square.fill", 0xE5E7EB)),
        ("/next/", ServerKind("Next.js", "n.square.fill", 0xE5E7EB)),
        ("nuxt", ServerKind("Nuxt", "mountain.2.fill", 0x34D399)),
        ("astro", ServerKind("Astro", "sparkles", 0xFF7A45)),
        ("remix", ServerKind("Remix", "r.square.fill", 0x60A5FA)),
        ("react-scripts", ServerKind("React", "atom", 0x61DAFB)),
        ("ng serve", ServerKind("Angular", "a.square.fill", 0xF43F5E)),
        ("@angular", ServerKind("Angular", "a.square.fill", 0xF43F5E)),
        ("storybook", ServerKind("Storybook", "book.fill", 0xFF4785)),
        ("expo", ServerKind("Expo", "iphone", 0xE5E7EB)),
        ("metro", ServerKind("Metro", "iphone", 0x60A5FA)),
        ("webpack", ServerKind("Webpack", "cube.fill", 0x8DD6F9)),
        ("parcel", ServerKind("Parcel", "shippingbox.fill", 0xFBBF24)),
        ("svelte", ServerKind("Svelte", "s.square.fill", 0xFF3E00)),
        ("artisan serve", ServerKind("Laravel", "flame.fill", 0xF05340)),
        ("symfony", ServerKind("Symfony", "s.circle.fill", 0xE5E7EB)),
        ("php -s", ServerKind("PHP", "chevron.left.forwardslash.chevron.right", 0x8892BF)),
        ("manage.py runserver", ServerKind("Django", "leaf.fill", 0x34D399)),
        ("uvicorn", ServerKind("FastAPI", "bolt.horizontal.fill", 0x2DD4BF)),
        ("gunicorn", ServerKind("Gunicorn", "tortoise.fill", 0x2DD4BF)),
        ("flask", ServerKind("Flask", "flask.fill", 0xE5E7EB)),
        ("http.server", ServerKind("Python HTTP", "globe", 0xFBBF24)),
        ("streamlit", ServerKind("Streamlit", "chart.bar.fill", 0xFF4B4B)),
        ("jupyter", ServerKind("Jupyter", "book.closed.fill", 0xF37626)),
        ("rails", ServerKind("Rails", "tram.fill", 0xCC0000)),
        ("puma", ServerKind("Puma", "pawprint.fill", 0xCC0000)),
        ("hugo", ServerKind("Hugo", "h.square.fill", 0xFF4088)),
        ("jekyll", ServerKind("Jekyll", "j.square.fill", 0xCC0000)),
        ("wrangler", ServerKind("Cloudflare", "cloud.fill", 0xF38020)),
        ("firebase", ServerKind("Firebase", "flame", 0xFFCA28)),
        ("live-server", ServerKind("Live Server", "dot.radiowaves.left.and.right", 0x60A5FA)),
        ("http-server", ServerKind("http-server", "globe", 0x60A5FA)),
        ("nodemon", ServerKind("Node.js", "hexagon.fill", 0x68A063)),
        ("ts-node", ServerKind("Node.js", "hexagon.fill", 0x68A063)),
        ("tsx ", ServerKind("Node.js", "hexagon.fill", 0x68A063)),
        ("bun", ServerKind("Bun", "circle.hexagongrid.fill", 0xFBF0DF)),
        ("deno", ServerKind("Deno", "tortoise", 0xE5E7EB)),
    ]

    static let serviceRules: [(String, ServerKind)] = [
        ("postgres", ServerKind("PostgreSQL", "cylinder.split.1x2.fill", 0x336791, browser: false)),
        ("mysqld", ServerKind("MySQL", "cylinder.fill", 0x00758F, browser: false)),
        ("mariadb", ServerKind("MariaDB", "cylinder.fill", 0xC0765A, browser: false)),
        ("redis-server", ServerKind("Redis", "square.stack.3d.up.fill", 0xDC382D, browser: false)),
        ("mongod", ServerKind("MongoDB", "leaf.fill", 0x47A248, browser: false)),
        ("memcached", ServerKind("Memcached", "memorychip.fill", 0x34D399, browser: false)),
        ("elasticsearch", ServerKind("Elasticsearch", "magnifyingglass", 0xFEC514)),
        ("rabbitmq", ServerKind("RabbitMQ", "hare.fill", 0xFF6600)),
        ("beam.smp", ServerKind("Erlang/RabbitMQ", "hare.fill", 0xFF6600, browser: false)),
        ("ollama", ServerKind("Ollama", "brain.head.profile", 0xE5E7EB)),
        ("mailpit", ServerKind("Mailpit", "envelope.fill", 0x60A5FA)),
        ("mailhog", ServerKind("MailHog", "envelope.fill", 0x60A5FA)),
        ("minio", ServerKind("MinIO", "externaldrive.fill.badge.icloud", 0xC72E49)),
        ("nginx", ServerKind("nginx", "server.rack", 0x009639)),
        ("httpd", ServerKind("Apache", "server.rack", 0xD22128)),
        ("caddy", ServerKind("Caddy", "lock.shield.fill", 0x22B638)),
        ("valet", ServerKind("Valet", "server.rack", 0xF05340)),
        ("dnsmasq", ServerKind("dnsmasq", "network", 0x94A3B8, browser: false)),
    ]

    static let dockerRules: [String] = ["com.docker", "vpnkit", "limactl", "colima", "orbstack", "rancher", "podman", "gvproxy"]

    public static func classify(_ s: ListeningSocket, _ d: ProcessDetails?) -> Classification {
        let name = d?.name ?? "?"
        let path = d?.path ?? ""
        let cmd = ((d?.commandLine ?? "") + " " + name).lowercased()

        if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/") || path.hasPrefix("/usr/sbin/")
            || path.hasPrefix("/sbin/") || (d?.uid == 0 && path.hasPrefix("/usr/")) {
            return Classification(category: .system, kind: systemKind(name, port: s.port))
        }
        if dockerRules.contains(where: { cmd.contains($0) }) {
            return Classification(category: .docker, kind: ServerKind("Docker", "shippingbox.fill", 0x2496ED))
        }
        for (k, kind) in serviceRules where cmd.contains(k) {
            return Classification(category: .services, kind: kind, projectName: nil, projectPath: nil)
        }
        if cmd.contains("claude") && !cmd.contains("vite") {
            return Classification(category: .apps, kind: ServerKind("Claude Code", "terminal.fill", 0xD97757, browser: false))
        }
        // Uygulama paketleri (Spotify, Warp, Figma…)
        if let r = path.range(of: ".app/") {
            let appName = (String(path[..<r.lowerBound]) as NSString).lastPathComponent
            if !looksLikeDevRuntime(name) {
                return Classification(category: .apps, kind: ServerKind(appName, "app.fill", 0x94A3B8, browser: false))
            }
        }
        // Geliştirme sunucuları
        let project = projectRoot(from: d?.cwd ?? scriptDir(d))
        var kind: ServerKind?
        for (k, v) in devRules where cmd.contains(k) { kind = v; break }
        if kind == nil {
            kind = runtimeKind(name)
        }
        if let kind {
            return Classification(category: .dev, kind: kind, projectName: project.map { projectName($0) }, projectPath: project)
        }
        if project != nil {
            return Classification(category: .dev, kind: ServerKind(name, "terminal.fill", 0x94A3B8),
                                  projectName: project.map { projectName($0) }, projectPath: project)
        }
        return Classification(category: .apps, kind: ServerKind(name, "gearshape.fill", 0x94A3B8, browser: false))
    }

    static func looksLikeDevRuntime(_ name: String) -> Bool {
        ["node", "php", "python", "python3", "ruby", "bun", "deno", "java", "go"].contains(name.lowercased())
    }

    static func runtimeKind(_ name: String) -> ServerKind? {
        let n = name.lowercased()
        if n == "node" { return ServerKind("Node.js", "hexagon.fill", 0x68A063) }
        if n.hasPrefix("php") { return ServerKind("PHP", "chevron.left.forwardslash.chevron.right", 0x8892BF) }
        if n.hasPrefix("python") { return ServerKind("Python", "chevron.left.forwardslash.chevron.right", 0xFFD43B) }
        if n == "ruby" { return ServerKind("Ruby", "diamond.fill", 0xCC342D) }
        if n == "java" { return ServerKind("Java", "cup.and.saucer.fill", 0xF89820) }
        if n == "go" || n.hasSuffix("-go") { return ServerKind("Go", "g.square.fill", 0x00ADD8) }
        if n == "dotnet" { return ServerKind(".NET", "n.circle.fill", 0x512BD4) }
        return nil
    }

    static func systemKind(_ name: String, port: UInt16) -> ServerKind {
        if name == "ControlCenter" && (port == 5000 || port == 7000) {
            return ServerKind(L("AirPlay Alıcısı", "AirPlay Receiver"), "airplayvideo", 0x94A3B8, browser: false)
        }
        if name == "rapportd" { return ServerKind(L("Süreklilik (rapportd)", "Continuity (rapportd)"), "link", 0x94A3B8, browser: false) }
        if name == "sharingd" { return ServerKind("AirDrop", "airplayaudio", 0x94A3B8, browser: false) }
        return ServerKind(name, "apple.logo", 0x94A3B8, browser: false)
    }

    static func scriptDir(_ d: ProcessDetails?) -> String? {
        guard let a = d?.arguments else { return nil }
        for x in a.dropFirst() where x.hasPrefix("/") && FileManager.default.fileExists(atPath: x) {
            return (x as NSString).deletingLastPathComponent
        }
        return nil
    }

    static let markers = ["package.json", "composer.json", ".git", "pyproject.toml", "requirements.txt", "Gemfile",
                          "go.mod", "Cargo.toml", "artisan", "manage.py", "deno.json", "bun.lockb", "pom.xml", "build.gradle"]

    /// Çalışma klasöründen yukarı çıkarak proje kökünü bulur (ev klasörünü geçmez).
    public static func projectRoot(from dir: String?) -> String? {
        guard var cur = dir, cur.hasPrefix(home), cur != home else { return nil }
        let fm = FileManager.default
        var best: String?
        for _ in 0..<12 {
            if markers.contains(where: { fm.fileExists(atPath: cur + "/" + $0) }) {
                best = cur
                // node_modules içindeyse dışarı çık
                if !cur.contains("/node_modules/") { break }
            }
            let up = (cur as NSString).deletingLastPathComponent
            if up == cur || up == home || !up.hasPrefix(home) { break }
            cur = up
        }
        return best ?? dir.flatMap { $0 == home ? nil : $0 }
    }

    public static func projectName(_ root: String) -> String {
        if let data = FileManager.default.contents(atPath: root + "/package.json"),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let n = obj["name"] as? String, !n.isEmpty, !n.contains("/") || n.hasPrefix("@") {
            return n
        }
        return (root as NSString).lastPathComponent
    }
}
