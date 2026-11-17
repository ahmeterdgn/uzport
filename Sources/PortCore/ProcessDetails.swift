import Darwin
import Foundation

/// Bir sürecin ayrıntıları: ad, yol, komut satırı, çalışma klasörü, bellek, başlama zamanı.
public struct ProcessDetails: Hashable, Sendable {
    public let pid: pid_t
    public let name: String
    public let path: String
    public let arguments: [String]
    public let cwd: String?
    public let startDate: Date?
    public let residentBytes: UInt64
    public let uid: uid_t
    public let parentPID: pid_t

    public init(pid: pid_t, name: String, path: String, arguments: [String], cwd: String?, startDate: Date?,
                residentBytes: UInt64, uid: uid_t, parentPID: pid_t) {
        self.pid = pid
        self.name = name
        self.path = path
        self.arguments = arguments
        self.cwd = cwd
        self.startDate = startDate
        self.residentBytes = residentBytes
        self.uid = uid
        self.parentPID = parentPID
    }

    public var commandLine: String { arguments.joined(separator: " ") }
    public var isOwnedByCurrentUser: Bool { uid == getuid() }

    public static func read(_ pid: pid_t) -> ProcessDetails? {
        var nameBuf = [CChar](repeating: 0, count: 1024)
        proc_name(pid, &nameBuf, UInt32(nameBuf.count))
        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
        let path = String(cString: pathBuf)

        var bsd = proc_bsdinfo()
        let hasBSD = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0
        var task = proc_taskinfo()
        let hasTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) > 0

        var name = String(cString: nameBuf)
        if name.isEmpty { name = (path as NSString).lastPathComponent }
        if name.isEmpty, hasBSD {
            name = withUnsafeBytes(of: bsd.pbi_comm) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        }

        return ProcessDetails(
            pid: pid,
            name: name,
            path: path,
            arguments: arguments(of: pid),
            cwd: cwd(of: pid),
            startDate: hasBSD ? Date(timeIntervalSince1970: TimeInterval(bsd.pbi_start_tvsec)) : nil,
            residentBytes: hasTask ? task.pti_resident_size : 0,
            uid: hasBSD ? bsd.pbi_uid : 0,
            parentPID: hasBSD ? pid_t(bsd.pbi_ppid) : 0
        )
    }

    /// KERN_PROCARGS2 ile komut satırı argümanları.
    static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buf, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size && buf[i] != 0 { i += 1 } // çalıştırılabilir yol
        while i < size && buf[i] == 0 { i += 1 }  // dolgu
        var args: [String] = []
        while args.count < argc && i < size {
            let start = i
            while i < size && buf[i] != 0 { i += 1 }
            args.append(String(decoding: buf[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }

    static func cwd(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let r = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.size))
        guard r > 0 else { return nil }
        let p = withUnsafeBytes(of: info.pvi_cdir.vip_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        return p.isEmpty || p == "/" ? nil : p
    }
}
