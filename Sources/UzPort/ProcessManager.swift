import AppKit
import Darwin
import Foundation
import PortCore

/// UzPort'un başlattığı bir sunucu.
@MainActor
final class ManagedServer: ObservableObject, Identifiable {
    enum State: Equatable {
        case starting, running, exited(Int32), stopped

        var isAlive: Bool { self == .starting || self == .running }
    }

    let id = UUID()
    let project: Project
    let command: RunCommand
    @Published var state: State = .starting
    @Published var pid: pid_t = 0
    @Published var lines: [String] = []
    @Published var detectedURL: URL?
    @Published var startedAt = Date()
    var autoRestart = false
    var restarts = 0
    var stopRequested = false
    fileprivate var partial = ""

    init(project: Project, command: RunCommand) {
        self.project = project
        self.command = command
    }

    var title: String { project.name }
    var lastLines: [String] { Array(lines.suffix(3)) }
}

@MainActor
final class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    @Published var servers: [ManagedServer] = []
    @Published var projects: [Project] = []
    @Published var scanningProjects = false

    @Published var roots: [String] = UserDefaults.standard.stringArray(forKey: "projectRoots") ?? ProjectScanner.defaultRoots {
        didSet { UserDefaults.standard.set(roots, forKey: "projectRoots"); rescanProjects() }
    }
    @Published var recent: [String] = UserDefaults.standard.stringArray(forKey: "recentProjects") ?? [] {
        didSet { UserDefaults.standard.set(recent, forKey: "recentProjects") }
    }

    static let maxLines = 4000

    func rescanProjects() {
        guard !scanningProjects, !DemoMode.isDemoData else { return }
        scanningProjects = true
        let r = roots
        Task.detached(priority: .utility) {
            let ps = ProjectScanner.scan(roots: r)
            await MainActor.run {
                ProcessManager.shared.projects = ps
                ProcessManager.shared.scanningProjects = false
            }
        }
    }

    func server(for project: Project) -> ManagedServer? {
        servers.last { $0.project.path == project.path && $0.state.isAlive }
    }

    /// Bir porttaki süreç, UzPort'un başlattığı bir sunucunun alt süreci mi?
    func owner(ofPID pid: pid_t, parents: (pid_t) -> pid_t) -> ManagedServer? {
        let alive = servers.filter { $0.state.isAlive && $0.pid > 0 }
        guard !alive.isEmpty else { return nil }
        var cur = pid
        for _ in 0..<16 {
            if let s = alive.first(where: { $0.pid == cur }) { return s }
            let p = parents(cur)
            if p <= 1 || p == cur { return nil }
            cur = p
        }
        return nil
    }

    @discardableResult
    func start(_ project: Project, _ command: RunCommand? = nil) -> ManagedServer? {
        guard let cmd = command ?? project.defaultCommand else { return nil }
        if let existing = server(for: project) { return existing }
        let s = ManagedServer(project: project, command: cmd)
        s.autoRestart = PortStore.shared.autoRestart
        servers.append(s)
        recent.removeAll { $0 == project.path }
        recent.insert(project.path, at: 0)
        if recent.count > 12 { recent.removeLast(recent.count - 12) }
        launch(s)
        return s
    }

    func restart(_ s: ManagedServer) {
        stop(s) { [weak self] in
            guard let self else { return }
            let n = ManagedServer(project: s.project, command: s.command)
            n.autoRestart = s.autoRestart
            if let i = self.servers.firstIndex(where: { $0.id == s.id }) { self.servers[i] = n } else { self.servers.append(n) }
            self.launch(n)
        }
    }

    func stop(_ s: ManagedServer, then: (() -> Void)? = nil) {
        s.stopRequested = true
        let pgid = s.pid
        guard pgid > 0, s.state.isAlive else { s.state = .stopped; then?(); return }
        Task.detached {
            Darwin.kill(-pgid, SIGTERM)
            for _ in 0..<30 {
                if Darwin.kill(-pgid, 0) != 0 { break }
                usleep(100_000)
            }
            if Darwin.kill(-pgid, 0) == 0 { Darwin.kill(-pgid, SIGKILL); usleep(200_000) }
            await MainActor.run {
                if s.state.isAlive { s.state = .stopped }
                then?()
            }
        }
    }

    func stopAll() {
        for s in servers where s.state.isAlive && s.pid > 0 {
            s.stopRequested = true
            Darwin.kill(-s.pid, SIGTERM)
        }
    }

    func remove(_ s: ManagedServer) {
        if s.state.isAlive { stop(s) }
        servers.removeAll { $0.id == s.id }
    }

    // MARK: Süreç başlatma

    private func launch(_ s: ManagedServer) {
        let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap { $0.isEmpty ? nil : $0 } ?? "/bin/zsh"
        let q = "'" + s.project.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        // Giriş + etkileşimli kabuk: nvm, asdf, Homebrew PATH ayarları yüklensin.
        let script = "cd \(q) && exec \(s.command.command)"
        s.lines.append("$ \(s.command.command)")
        s.lines.append("  \(s.project.path)")

        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { s.state = .exited(-1); return }
        let readFD = fds[0], writeFD = fds[1]

        var fa: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fa)
        posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&fa, writeFD, 1)
        posix_spawn_file_actions_adddup2(&fa, writeFD, 2)
        posix_spawn_file_actions_addclose(&fa, readFD)
        posix_spawn_file_actions_addclose(&fa, writeFD)

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        // Kendi süreç grubu: durdururken npm'in başlattığı tüm alt süreçler de kapanır.
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF))
        posix_spawnattr_setpgroup(&attr, 0)
        var sigs = sigset_t()
        sigfillset(&sigs)
        posix_spawnattr_setsigdefault(&attr, &sigs)

        var env = ProcessInfo.processInfo.environment
        env["BROWSER"] = "none"          // CRA/Vite tarayıcıyı kendiliğinden açmasın
        env["FORCE_COLOR"] = "1"
        env["TERM"] = "xterm-256color"
        env["UZPORT"] = "1"
        let envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        let args = [shell, "-l", "-i", "-c", script]
        let argv = args.map { strdup($0) } + [nil]
        defer {
            envp.forEach { free($0) }
            argv.forEach { free($0) }
            posix_spawn_file_actions_destroy(&fa)
            posix_spawnattr_destroy(&attr)
        }

        var pid: pid_t = 0
        let rc = posix_spawn(&pid, shell, &fa, &attr, argv, envp)
        close(writeFD)
        guard rc == 0 else {
            close(readFD)
            s.lines.append(L("Başlatılamadı: \(String(cString: strerror(rc)))", "Couldn't start: \(String(cString: strerror(rc)))"))
            s.state = .exited(Int32(rc))
            return
        }
        s.pid = pid
        s.startedAt = Date()
        s.state = .starting

        // Çıktıyı oku
        let reader = Thread { [weak s] in
            var buf = [UInt8](repeating: 0, count: 32 * 1024)
            while true {
                let n = buf.withUnsafeMutableBytes { read(readFD, $0.baseAddress, $0.count) }
                if n < 0 && errno == EINTR { continue }
                if n <= 0 { break }
                let chunk = String(decoding: buf[0..<n], as: UTF8.self)
                Task { @MainActor in s.map { ProcessManager.append(chunk, to: $0) } }
            }
            close(readFD)
        }
        reader.start()

        // Çıkışı bekle
        let waiter = Thread { [weak self, weak s] in
            var status: Int32 = 0
            while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
            let code: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : -(status & 0x7f)
            Task { @MainActor in
                guard let s else { return }
                // Grup içinde kalan süreçleri de temizle (ör. node, kabuk çıktıktan sonra).
                Darwin.kill(-pid, SIGTERM)
                if s.stopRequested {
                    s.state = .stopped
                    s.lines.append(L("■ Durduruldu", "■ Stopped"))
                } else {
                    s.state = .exited(code)
                    s.lines.append(L("✕ Süreç kapandı (çıkış kodu \(code))", "✕ Process exited (code \(code))"))
                    if s.autoRestart && s.restarts < 5 && Date().timeIntervalSince(s.startedAt) > 3 {
                        s.restarts += 1
                        self?.restartCrashed(s)
                    } else {
                        PortStore.shared.show(L("\(s.title) kapandı", "\(s.title) exited"))
                    }
                }
            }
        }
        waiter.start()
    }

    private func restartCrashed(_ s: ManagedServer) {
        let n = ManagedServer(project: s.project, command: s.command)
        n.autoRestart = true
        n.restarts = s.restarts
        n.lines = s.lines.suffix(200) + [L("↻ Otomatik yeniden başlatılıyor…", "↻ Auto-restarting…")]
        if let i = servers.firstIndex(where: { $0.id == s.id }) { servers[i] = n }
        launch(n)
    }

    static func append(_ chunk: String, to s: ManagedServer) {
        let text = s.partial + chunk
        var parts = text.components(separatedBy: "\n")
        s.partial = parts.removeLast()
        guard !parts.isEmpty else { return }
        for p in parts {
            let clean = ANSI.strip(p)
            if s.detectedURL == nil, let u = ANSI.detectURL(clean) { s.detectedURL = u }
            s.lines.append(clean)
        }
        if s.lines.count > maxLines { s.lines.removeFirst(s.lines.count - maxLines) }
        if s.state == .starting && s.detectedURL != nil { s.state = .running }
    }
}
