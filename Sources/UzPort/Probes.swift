import AppKit
import Foundation
import PortCore

/// localhost sunucusundan sayfa başlığı, durum kodu ve favicon alır.
enum HTTPProbe {
    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 2
        c.timeoutIntervalForResource = 3
        c.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: c)
    }()

    static func probe(port: UInt16) async -> ProbeResult {
        guard let url = URL(string: "http://localhost:\(port)/") else { return ProbeResult() }
        var req = URLRequest(url: url)
        req.setValue("text/html,*/*", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await session.data(for: req), let http = resp as? HTTPURLResponse else {
            return ProbeResult()
        }
        var r = ProbeResult(status: http.statusCode, server: http.value(forHTTPHeaderField: "Server"))
        let html = String(decoding: data.prefix(96_000), as: UTF8.self)
        r.pageTitle = firstMatch(#"<title[^>]*>([\s\S]*?)</title>"#, in: html)
            .map { decodeEntities($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .flatMap { $0.isEmpty ? nil : String($0.prefix(80)) }

        var iconPaths: [String] = []
        if let href = firstMatch(#"<link[^>]+rel=["'][^"']*icon[^"']*["'][^>]*href=["']([^"']+)["']"#, in: html)
            ?? firstMatch(#"<link[^>]+href=["']([^"']+)["'][^>]*rel=["'][^"']*icon[^"']*["']"#, in: html) {
            iconPaths.append(href)
        }
        iconPaths.append("/favicon.ico")
        for p in iconPaths {
            guard let u = URL(string: p, relativeTo: url),
                  let (d, rs) = try? await session.data(from: u),
                  (rs as? HTTPURLResponse)?.statusCode == 200, d.count > 0, d.count < 2_000_000,
                  let img = NSImage(data: d), img.isValid else { continue }
            r.favicon = img
            break
        }
        return r
    }

    static func firstMatch(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&#x27;", with: "'")
    }
}

/// `docker ps` ile host portu → konteyner adı eşlemesi (Docker Desktop, Colima, OrbStack).
enum DockerPorts {
    static let candidates = ["/opt/homebrew/bin/docker", "/usr/local/bin/docker", "/usr/bin/docker",
                             "/Applications/Docker.app/Contents/Resources/bin/docker", NSHomeDirectory() + "/.orbstack/bin/docker"]

    static func read() -> [UInt16: (name: String, image: String)] {
        guard let bin = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return [:] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["ps", "--format", "{{.Names}}|{{.Image}}|{{.Ports}}"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [:] }
        let deadline = Date().addingTimeInterval(3)
        while p.isRunning && Date() < deadline { usleep(50_000) }
        if p.isRunning { p.terminate(); return [:] }
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return parse(text)
    }

    /// "web|nginx:latest|0.0.0.0:8080->80/tcp, :::8080->80/tcp"
    static func parse(_ text: String) -> [UInt16: (name: String, image: String)] {
        var map: [UInt16: (String, String)] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            for m in parts[2].split(separator: ",") {
                let seg = m.trimmingCharacters(in: .whitespaces)
                guard let arrow = seg.range(of: "->") else { continue }
                let host = seg[..<arrow.lowerBound]
                if let colon = host.lastIndex(of: ":"), let port = UInt16(host[host.index(after: colon)...]) {
                    map[port] = (parts[0], parts[1])
                }
            }
        }
        return map
    }
}
