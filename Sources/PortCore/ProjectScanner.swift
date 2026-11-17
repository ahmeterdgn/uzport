import Foundation

/// Çalıştırılabilir bir komut (ör. "dev" → "pnpm run dev").
public struct RunCommand: Hashable, Codable, Sendable, Identifiable {
    public var id: String { command }
    public let label: String
    public let command: String

    public init(label: String, command: String) {
        self.label = label
        self.command = command
    }
}

/// Diskteki bir proje ve başlatılabilecek komutları.
public struct Project: Hashable, Codable, Sendable, Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let kindName: String
    public let commands: [RunCommand]

    public init(name: String, path: String, kindName: String, commands: [RunCommand]) {
        self.name = name
        self.path = path
        self.kindName = kindName
        self.commands = commands
    }

    public var defaultCommand: RunCommand? { commands.first }
}

public enum ProjectScanner {
    static let skip: Set<String> = ["node_modules", ".git", "vendor", "build", "dist", ".build", "Pods", ".next",
                                    ".nuxt", "target", "venv", ".venv", "__pycache__", "DerivedData", ".cache", "coverage"]

    /// Varsayılan proje klasörleri (var olanlar).
    public static var defaultRoots: [String] {
        let h = NSHomeDirectory()
        return ["Desktop/devs", "Developer", "Projects", "projects", "code", "Code", "dev", "Sites", "src", "repos", "workspace"]
            .map { h + "/" + $0 }
            .filter { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: $0, isDirectory: &d) && d.boolValue }
    }

    /// Kökler altında (en fazla `depth` seviye) başlatılabilir projeleri bulur.
    public static func scan(roots: [String], depth: Int = 3) -> [Project] {
        var out: [Project] = []
        var seen = Set<String>()
        func walk(_ dir: String, _ level: Int) {
            if let p = project(at: dir) {
                if seen.insert(p.path).inserted { out.append(p) }
                // Monorepo: alt paketlere de bak.
                if !(FileManager.default.fileExists(atPath: dir + "/pnpm-workspace.yaml")
                     || FileManager.default.fileExists(atPath: dir + "/lerna.json")
                     || FileManager.default.fileExists(atPath: dir + "/turbo.json")) { return }
            }
            guard level < depth, let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            for name in items.sorted() where !name.hasPrefix(".") && !skip.contains(name) {
                let sub = dir + "/" + name
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue else { continue }
                walk(sub, level + 1)
            }
        }
        for r in roots { walk(r, 0) }
        return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Bir klasör başlatılabilir bir proje mi? Komutlarıyla birlikte döner.
    public static func project(at dir: String) -> Project? {
        let fm = FileManager.default
        func has(_ f: String) -> Bool { fm.fileExists(atPath: dir + "/" + f) }
        var cmds: [RunCommand] = []
        var kind = ""
        var name = (dir as NSString).lastPathComponent

        if has("package.json"), let data = fm.contents(atPath: dir + "/package.json"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let n = json["name"] as? String, !n.isEmpty { name = n }
            let pm = has("pnpm-lock.yaml") ? "pnpm" : has("yarn.lock") ? "yarn" : (has("bun.lockb") || has("bun.lock")) ? "bun" : "npm"
            let scripts = json["scripts"] as? [String: String] ?? [:]
            let preferred = ["dev", "start", "serve", "develop", "preview", "storybook", "watch"]
            for key in preferred where scripts[key] != nil {
                cmds.append(RunCommand(label: key, command: pm == "npm" && key == "start" ? "npm start" : "\(pm) run \(key)"))
            }
            for key in scripts.keys.sorted() where !preferred.contains(key) && looksLikeServer(key, scripts[key] ?? "") {
                cmds.append(RunCommand(label: key, command: "\(pm) run \(key)"))
            }
            let deps = ((json["dependencies"] as? [String: Any]) ?? [:]).merging((json["devDependencies"] as? [String: Any]) ?? [:]) { a, _ in a }
            kind = deps["next"] != nil ? "Next.js" : deps["nuxt"] != nil ? "Nuxt" : deps["astro"] != nil ? "Astro"
                : deps["@sveltejs/kit"] != nil ? "SvelteKit" : deps["@remix-run/dev"] != nil ? "Remix"
                : deps["vite"] != nil ? "Vite" : deps["@angular/core"] != nil ? "Angular" : deps["expo"] != nil ? "Expo"
                : deps["express"] != nil ? "Express" : deps["@nestjs/core"] != nil ? "NestJS" : "Node.js"
        }
        if has("artisan") {
            cmds.insert(RunCommand(label: "serve", command: "php artisan serve"), at: 0)
            kind = "Laravel"
        } else if has("composer.json") && cmds.isEmpty {
            let docroot = has("public/index.php") ? "public" : "."
            cmds.append(RunCommand(label: "php -S", command: "php -S localhost:8000 -t \(docroot)"))
            kind = "PHP"
        }
        if has("manage.py") {
            cmds.insert(RunCommand(label: "runserver", command: "python3 manage.py runserver"), at: 0)
            kind = "Django"
        }
        if has("bin/rails") {
            cmds.insert(RunCommand(label: "server", command: "bin/rails server"), at: 0)
            kind = "Rails"
        }
        if has("hugo.toml") || has("hugo.yaml") || (has("config.toml") && has("content")) {
            cmds.append(RunCommand(label: "hugo", command: "hugo server"))
            kind = kind.isEmpty ? "Hugo" : kind
        }
        for f in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"] where has(f) {
            cmds.append(RunCommand(label: "compose", command: "docker compose up"))
            if kind.isEmpty { kind = "Docker Compose" }
            break
        }
        guard !cmds.isEmpty else { return nil }
        return Project(name: name, path: dir, kindName: kind.isEmpty ? "Proje" : kind, commands: cmds)
    }

    static func looksLikeServer(_ key: String, _ script: String) -> Bool {
        let k = key.lowercased()
        let bad = ["build", "test", "lint", "format", "typecheck", "type-check", "deploy", "clean", "prepare",
                   "postinstall", "preinstall", "generate", "e2e", "release", "publish", "check", "migrate", "seed"]
        if bad.contains(where: { k.contains($0) }) { return false }
        let sc = script.lowercased()
        if sc.contains(" build") || sc.hasPrefix("tsc") || sc.contains("jest") || sc.contains("vitest") { return false }
        let s = k + " " + sc
        return ["serve", "server", "vite", "next dev", "nodemon", "webpack serve", "http-server", "live-server", "astro dev"]
            .contains { s.contains($0) }
    }
}

/// ANSI renk kodlarını ve kontrol karakterlerini temizler.
public enum ANSI {
    public static func strip(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var it = s.unicodeScalars.makeIterator()
        while let c = it.next() {
            if c == "\u{1B}" {
                guard let n = it.next() else { break }
                if n == "[" {
                    while let x = it.next(), !(0x40...0x7E).contains(x.value) {}
                } else if n == "]" {
                    while let x = it.next(), x != "\u{07}", x != "\u{1B}" {}
                }
                continue
            }
            if c == "\r" { continue }
            out.unicodeScalars.append(c)
        }
        return out
    }

    /// Log satırından yerel sunucu adresini yakalar ("Local: http://localhost:5173/").
    public static func detectURL(_ line: String) -> URL? {
        guard let r = line.range(of: #"https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1?\])(:\d+)?[^\s]*"#, options: .regularExpression) else { return nil }
        return URL(string: String(line[r]).replacingOccurrences(of: "0.0.0.0", with: "localhost"))
    }
}
