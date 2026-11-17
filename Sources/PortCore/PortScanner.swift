import Darwin
import Foundation

/// Dinlenen bir TCP portu ve onu tutan süreç.
public struct ListeningSocket: Hashable, Sendable {
    public let pid: pid_t
    public let port: UInt16
    public let address: String   // "127.0.0.1", "::", "*"
    public let isIPv6: Bool

    public init(pid: pid_t, port: UInt16, address: String, isIPv6: Bool) {
        self.pid = pid
        self.port = port
        self.address = address
        self.isIPv6 = isIPv6
    }

    public var isLoopbackOnly: Bool {
        address == "127.0.0.1" || address == "::1"
    }
}

/// `lsof` çalıştırmadan, libproc ile dinlenen TCP portlarını bulur.
/// Kullanıcının kendi süreçlerini yönetici izni olmadan görür.
public enum PortScanner {
    public static func allPIDs() -> [pid_t] {
        let n = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard n > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(n) / MemoryLayout<pid_t>.size + 64)
        let got = pids.withUnsafeMutableBytes { proc_listpids(UInt32(PROC_ALL_PIDS), 0, $0.baseAddress, Int32($0.count)) }
        guard got > 0 else { return [] }
        return Array(pids.prefix(Int(got) / MemoryLayout<pid_t>.size)).filter { $0 > 0 }
    }

    /// Bir sürecin dinlediği TCP soketleri.
    public static func listeningSockets(of pid: pid_t) -> [ListeningSocket] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: count + 16)
        let got = fds.withUnsafeMutableBytes { proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count)) }
        guard got > 0 else { return [] }
        let n = Int(got) / MemoryLayout<proc_fdinfo>.stride

        var out: [ListeningSocket] = []
        for fd in fds.prefix(n) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var si = socket_fdinfo()
            let r = proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &si, Int32(MemoryLayout<socket_fdinfo>.size))
            guard r == Int32(MemoryLayout<socket_fdinfo>.size) else { continue }
            guard si.psi.soi_kind == Int32(SOCKINFO_TCP) else { continue }
            let tcp = si.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == Int32(TSI_S_LISTEN) else { continue }
            let ini = tcp.tcpsi_ini
            let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport))
            guard port > 0 else { continue }
            let v6 = ini.insi_vflag & UInt8(INI_IPV6) != 0
            out.append(ListeningSocket(pid: pid, port: port, address: address(ini, v6: v6), isIPv6: v6))
        }
        return out
    }

    static func address(_ ini: in_sockinfo, v6: Bool) -> String {
        var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        if v6 {
            var a = ini.insi_laddr.ina_6
            if withUnsafeBytes(of: &a, { $0.allSatisfy { $0 == 0 } }) { return "*" }
            inet_ntop(AF_INET6, &a, &buf, socklen_t(buf.count))
        } else {
            var a = ini.insi_laddr.ina_46.i46a_addr4
            if a.s_addr == 0 { return "*" }
            inet_ntop(AF_INET, &a, &buf, socklen_t(buf.count))
        }
        return String(cString: buf)
    }

    /// Tüm dinlenen portlar (aynı süreç+port için IPv4/IPv6 kopyaları birleştirilir).
    public static func scan() -> [ListeningSocket] {
        var seen = Set<String>()
        var out: [ListeningSocket] = []
        for pid in allPIDs() {
            for s in listeningSockets(of: pid) {
                let key = "\(s.pid):\(s.port)"
                if seen.insert(key).inserted {
                    out.append(s)
                } else if let i = out.firstIndex(where: { $0.pid == s.pid && $0.port == s.port }),
                          out[i].isLoopbackOnly && !s.isLoopbackOnly {
                    out[i] = s // dışa açık olan adresi tercih et
                }
            }
        }
        return out.sorted { $0.port < $1.port }
    }
}
