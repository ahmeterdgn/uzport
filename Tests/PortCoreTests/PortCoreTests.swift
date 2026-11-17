import Darwin
import XCTest
@testable import PortCore

final class PortCoreTests: XCTestCase {
    /// Test sürecinde gerçek bir dinleme soketi açar; port numarasını döner.
    func openListener() throws -> (fd: Int32, port: UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let b = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        XCTAssertEqual(b, 0)
        XCTAssertEqual(listen(fd, 4), 0)
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        return (fd, UInt16(bigEndian: addr.sin_port))
    }

    func testScannerFindsOwnListener() throws {
        let (fd, port) = try openListener()
        defer { close(fd) }
        let found = PortScanner.scan().first { $0.port == port }
        XCTAssertNotNil(found, "kendi açtığımız port \(port) bulunmalı")
        XCTAssertEqual(found?.pid, getpid())
        XCTAssertEqual(found?.address, "127.0.0.1")
        XCTAssertTrue(found?.isLoopbackOnly ?? false)
    }

    func testClosedListenerDisappears() throws {
        let (fd, port) = try openListener()
        close(fd)
        XCTAssertNil(PortScanner.scan().first { $0.port == port && $0.pid == getpid() })
    }

    func testProcessDetailsOfSelf() throws {
        let d = try XCTUnwrap(ProcessDetails.read(getpid()))
        XCTAssertEqual(d.pid, getpid())
        XCTAssertFalse(d.name.isEmpty)
        XCTAssertFalse(d.arguments.isEmpty)
        XCTAssertTrue(d.isOwnedByCurrentUser)
        XCTAssertGreaterThan(d.residentBytes, 0)
        XCTAssertNotNil(d.startDate)
    }

    func details(name: String, path: String, args: [String], cwd: String? = nil, uid: uid_t = getuid()) -> ProcessDetails {
        ProcessDetails(pid: 4242, name: name, path: path, arguments: args, cwd: cwd, startDate: nil,
                       residentBytes: 0, uid: uid, parentPID: 1)
    }

    func sock(_ port: UInt16) -> ListeningSocket { ListeningSocket(pid: 4242, port: port, address: "127.0.0.1", isIPv6: false) }

    func testClassifiesDevServers() throws {
        let home = NSHomeDirectory()
        let proj = home + "/uzport-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: proj + "/src", withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: proj) }
        try #"{"name":"harika-site"}"#.write(toFile: proj + "/package.json", atomically: true, encoding: .utf8)

        let vite = Classifier.classify(sock(5173), details(name: "node", path: "/opt/homebrew/bin/node",
                                                          args: ["node", proj + "/node_modules/.bin/vite"], cwd: proj + "/src"))
        XCTAssertEqual(vite.category, .dev)
        XCTAssertEqual(vite.kind.name, "Vite")
        XCTAssertEqual(vite.projectName, "harika-site")
        XCTAssertEqual(vite.projectPath, proj)

        let laravel = Classifier.classify(sock(8000), details(name: "php", path: "/opt/homebrew/bin/php",
                                                             args: ["php", "artisan", "serve"], cwd: proj))
        XCTAssertEqual(laravel.kind.name, "Laravel")
        XCTAssertEqual(laravel.category, .dev)
    }

    func testClassifiesServicesDockerAppsSystem() {
        XCTAssertEqual(Classifier.classify(sock(5432), details(name: "postgres", path: "/opt/homebrew/opt/postgresql@16/bin/postgres", args: ["postgres", "-D", "x"])).kind.name, "PostgreSQL")
        XCTAssertEqual(Classifier.classify(sock(6379), details(name: "redis-server", path: "/opt/homebrew/bin/redis-server", args: ["redis-server"])).category, .services)
        XCTAssertEqual(Classifier.classify(sock(49770), details(name: "limactl", path: "/opt/homebrew/bin/limactl", args: ["limactl", "usernet"])).category, .docker)
        XCTAssertEqual(Classifier.classify(sock(7768), details(name: "Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify", args: ["Spotify"])).category, .apps)
        let airplay = Classifier.classify(sock(5000), details(name: "ControlCenter", path: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter", args: []))
        XCTAssertEqual(airplay.category, .system)
        XCTAssertFalse(airplay.kind.opensInBrowser)
    }

    func testProjectRootStopsAtHome() {
        XCTAssertNil(Classifier.projectRoot(from: NSHomeDirectory()))
        XCTAssertNil(Classifier.projectRoot(from: "/tmp"))
    }

    func testKillTerminatesChild() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sleep")
        p.arguments = ["30"]
        try p.run()
        let r = ProcessKiller.terminate(p.processIdentifier)
        XCTAssertTrue(r == .terminated || r == .killed)
        p.waitUntilExit()
        XCTAssertFalse(p.isRunning)
    }

    func testCannotKillSystemProcess() {
        XCTAssertEqual(ProcessKiller.terminate(1), .notFound) // launchd korunur
    }

    func testLanIP() {
        if let ip = NetworkInfo.lanIPv4() {
            XCTAssertEqual(ip.split(separator: ".").count, 4)
        }
    }
}

final class ProjectScannerTests: XCTestCase {
    var root = ""

    override func setUpWithError() throws {
        root = NSTemporaryDirectory() + "uzport-proj-\(UUID().uuidString)"
        let fm = FileManager.default
        func write(_ rel: String, _ s: String) throws {
            let p = root + "/" + rel
            try fm.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try s.write(toFile: p, atomically: true, encoding: .utf8)
        }
        try write("web/package.json", #"{"name":"moon-web","scripts":{"dev":"vite","build":"vite build","lint":"eslint .","test":"vitest","dev:server":"nodemon server.js"},"devDependencies":{"vite":"5"}}"#)
        try write("web/pnpm-lock.yaml", "")
        try write("api/artisan", "")
        try write("api/composer.json", "{}")
        try write("site/manage.py", "")
        try write("stack/docker-compose.yml", "services: {}")
        try write("lib/package.json", #"{"name":"just-lib","scripts":{"build":"tsc"}}"#)
        try write("web/node_modules/x/package.json", #"{"name":"x","scripts":{"dev":"vite"}}"#)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(atPath: root) }

    func testFindsRunnableProjects() {
        let ps = ProjectScanner.scan(roots: [root])
        let byName = Dictionary(uniqueKeysWithValues: ps.map { ($0.name, $0) })
        XCTAssertEqual(byName["moon-web"]?.defaultCommand?.command, "pnpm run dev")
        XCTAssertEqual(byName["moon-web"]?.kindName, "Vite")
        XCTAssertEqual(byName["moon-web"]?.commands.map(\.label), ["dev", "dev:server"], "build/lint/test sunucu değildir")
        XCTAssertEqual(byName["api"]?.defaultCommand?.command, "php artisan serve")
        XCTAssertEqual(byName["site"]?.defaultCommand?.command, "python3 manage.py runserver")
        XCTAssertEqual(byName["stack"]?.defaultCommand?.command, "docker compose up")
        XCTAssertNil(byName["just-lib"], "dev/start komutu olmayan kütüphane listelenmemeli")
        XCTAssertNil(byName["x"], "node_modules taranmamalı")
    }

    func testANSIStripAndURLDetection() {
        let line = "  \u{1B}[32m➜\u{1B}[39m  \u{1B}[1mLocal\u{1B}[22m:   \u{1B}[36mhttp://localhost:\u{1B}[1m5173\u{1B}[22m/\u{1B}[39m\r"
        let clean = ANSI.strip(line)
        XCTAssertEqual(clean, "  ➜  Local:   http://localhost:5173/")
        XCTAssertEqual(ANSI.detectURL(clean)?.absoluteString, "http://localhost:5173/")
        XCTAssertEqual(ANSI.detectURL("Server running on http://0.0.0.0:8000")?.absoluteString, "http://localhost:8000")
        XCTAssertNil(ANSI.detectURL("see https://example.com"))
    }
}
