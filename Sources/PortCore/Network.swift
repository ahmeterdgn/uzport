import Darwin
import Foundation

public enum NetworkInfo {
    /// Aynı ağdaki cihazların erişebileceği IPv4 adresi (Wi-Fi/Ethernet).
    public static func lanIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var candidates: [(String, String)] = []
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let sa = i.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(i.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let name = String(cString: i.ifa_name)
            let ip = String(cString: host)
            if ip.hasPrefix("169.254.") { continue }
            candidates.append((name, ip))
        }
        return (candidates.first { $0.0 == "en0" } ?? candidates.first { $0.0.hasPrefix("en") } ?? candidates.first)?.1
    }

    /// Port şu an boş mu? (bağlanmayı deneyerek)
    public static func isPortFree(_ port: UInt16) -> Bool {
        !PortScanner.scan().contains { $0.port == port }
    }
}

/// Bir süreci nazikçe (SIGTERM), gerekirse zorla (SIGKILL) kapatır.
public enum ProcessKiller {
    public enum Result: Equatable { case terminated, killed, notPermitted, notFound, stillRunning }

    public static func isAlive(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 || errno == EPERM }

    public static func terminate(_ pid: pid_t, force: Bool = false, wait seconds: Double = 2.5) -> Result {
        guard pid > 1 else { return .notFound }
        if kill(pid, force ? SIGKILL : SIGTERM) != 0 {
            return errno == EPERM ? .notPermitted : .notFound
        }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if kill(pid, 0) != 0 && errno == ESRCH { return force ? .killed : .terminated }
            usleep(100_000)
        }
        if !force {
            kill(pid, SIGKILL)
            usleep(300_000)
            if kill(pid, 0) != 0 && errno == ESRCH { return .killed }
        }
        return .stillRunning
    }
}
