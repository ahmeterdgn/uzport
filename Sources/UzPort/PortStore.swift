import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications
import PortCore

struct PortItem: Identifiable, Hashable {
    let socket: ListeningSocket
    let details: ProcessDetails?
    var cls: Classification
    var dockerName: String?
    var dockerImage: String?
    var extraPorts: [UInt16] = []

    var id: String { "\(socket.pid):\(socket.port)" }
    var port: UInt16 { socket.port }
    var pid: pid_t { socket.pid }
    var localURL: URL { URL(string: "http://localhost:\(port)")! }

    var title: String {
        if let d = dockerName { return d }
        return cls.projectName ?? cls.kind.name
    }

    var canKill: Bool { details?.isOwnedByCurrentUser == true && cls.category != .system }
}

struct ProbeResult: Hashable {
    var status: Int?
    var pageTitle: String?
    var favicon: NSImage?
    var server: String?
}

@MainActor
final class PortStore: ObservableObject {
    static let shared = PortStore()

    @Published var items: [PortItem] = []
    @Published var probes: [String: ProbeResult] = [:]
    @Published var query = ""
    @Published var toast: String?
    @Published var lan: String?
    @Published var armedKill: String?
    @Published var langVersion = 0

    @AppStorage("showSystem") var showSystem = false
    @AppStorage("showApps") var showApps = true
    @AppStorage("notify") var notify = true

    private var timer: Timer?
    private var knownIDs = Set<String>()
    private var firstScan = true
    private var docker: [UInt16: (name: String, image: String)] = [:]
    private var lastDocker = Date.distantPast
    private var probing = Set<String>()
    private var scanning = false

    var activeCount: Int { items.filter { $0.cls.category == .dev || $0.cls.category == .services || $0.cls.category == .docker }.count }

    func start() {
        guard timer == nil, !DemoMode.isDemoData else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in PortStore.shared.refresh() }
        }
        if notify {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        let needDocker = Date().timeIntervalSince(lastDocker) > 8
        Task.detached(priority: .utility) {
            let sockets = PortScanner.scan()
            var cache: [pid_t: ProcessDetails?] = [:]
            var out: [PortItem] = []
            for s in sockets {
                if cache[s.pid] == nil { cache[s.pid] = ProcessDetails.read(s.pid) }
                let d = cache[s.pid] ?? nil
                out.append(PortItem(socket: s, details: d, cls: Classifier.classify(s, d)))
            }
            let dmap = needDocker ? DockerPorts.read() : nil
            let lan = NetworkInfo.lanIPv4()
            let result = out
            await MainActor.run {
                let store = PortStore.shared
                if let dmap { store.docker = dmap; store.lastDocker = Date() }
                store.apply(result)
                store.lan = lan
                store.scanning = false
            }
        }
    }

    private func apply(_ fresh: [PortItem]) {
        var list = fresh
        for i in list.indices {
            if let d = docker[list[i].port] {
                list[i].dockerName = d.name
                list[i].dockerImage = d.image
                list[i].cls.category = .docker
            }
        }
        // Uygulama ve sistem süreçlerinin birden çok portunu tek satırda topla.
        var merged: [PortItem] = []
        var byPID: [pid_t: Int] = [:]
        for it in list {
            if it.cls.category == .apps || it.cls.category == .system, let i = byPID[it.pid] {
                merged[i].extraPorts.append(it.port)
            } else {
                if it.cls.category == .apps || it.cls.category == .system { byPID[it.pid] = merged.count }
                merged.append(it)
            }
        }
        list = merged
        let ids = Set(list.map(\.id))
        if !firstScan {
            for it in list where !knownIDs.contains(it.id) && it.cls.category == .dev { announce(it) }
        }
        firstScan = false
        knownIDs = ids
        if list != items { items = list }
        for it in list where shouldProbe(it) { probe(it) }
        probes = probes.filter { ids.contains($0.key) }
        if let a = armedKill, !ids.contains(a) { armedKill = nil }
    }

    func visible(_ c: PortCategory) -> [PortItem] {
        if c == .system && !showSystem { return [] }
        if c == .apps && !showApps { return [] }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return items.filter { it in
            guard it.cls.category == c else { return false }
            if q.isEmpty { return true }
            if let p = UInt16(q) { return it.port == p || String(it.port).hasPrefix(q) }
            let hay = [it.title, it.cls.kind.name, it.details?.name ?? "", it.cls.projectPath ?? "",
                       probes[it.id]?.pageTitle ?? "", String(it.port)].joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    /// Arama kutusuna yazılan sayı bir port mu? Doluysa kim tutuyor?
    var queriedPort: UInt16? { UInt16(query.trimmingCharacters(in: .whitespaces)) }

    // MARK: HTTP yoklama

    private func shouldProbe(_ it: PortItem) -> Bool {
        it.cls.kind.opensInBrowser && (it.cls.category == .dev || it.cls.category == .services || it.cls.category == .docker)
            && probes[it.id] == nil && !probing.contains(it.id)
    }

    private func probe(_ it: PortItem) {
        probing.insert(it.id)
        let id = it.id
        let port = it.port
        Task.detached(priority: .utility) {
            let r = await HTTPProbe.probe(port: port)
            await MainActor.run {
                PortStore.shared.probes[id] = r
                PortStore.shared.probing.remove(id)
            }
        }
    }

    // MARK: Eylemler

    func open(_ it: PortItem) {
        if it.cls.kind.opensInBrowser || probes[it.id]?.status != nil {
            NSWorkspace.shared.open(it.localURL)
        } else if let p = it.cls.projectPath {
            NSWorkspace.shared.open(URL(fileURLWithPath: p))
        }
    }

    func copyURL(_ it: PortItem, lan useLAN: Bool = false) {
        let s = useLAN ? "http://\(lan ?? "localhost"):\(it.port)" : it.localURL.absoluteString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        show(L("Kopyalandı: \(s)", "Copied: \(s)"))
    }

    func reveal(_ it: PortItem) {
        if let p = it.cls.projectPath {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
        } else if let path = it.details?.path, !path.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }

    static let editors = ["com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "dev.zed.Zed", "com.jetbrains.WebStorm",
                          "com.jetbrains.PhpStorm", "com.jetbrains.intellij", "com.sublimetext.4", "com.apple.dt.Xcode"]
    static let terminals = ["dev.warp.Warp-Stable", "com.googlecode.iterm2", "com.mitchellh.ghostty", "net.kovidgoyal.kitty", "com.apple.Terminal"]

    func appURL(_ ids: [String]) -> URL? {
        for id in ids { if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return u } }
        return nil
    }

    var editorName: String? { appURL(Self.editors).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } }

    func openIn(_ it: PortItem, apps: [String]) {
        guard let p = it.cls.projectPath, let app = appURL(apps) else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([URL(fileURLWithPath: p)], withApplicationAt: app, configuration: cfg)
    }

    func kill(_ it: PortItem) {
        guard it.canKill else { return }
        if armedKill != it.id {
            armedKill = it.id
            Task { try? await Task.sleep(nanoseconds: 3_000_000_000); if armedKill == it.id { armedKill = nil } }
            return
        }
        armedKill = nil
        let pid = it.pid
        let label = ":\(it.port) \(it.title)"
        Task.detached {
            let r = ProcessKiller.terminate(pid)
            await MainActor.run {
                switch r {
                case .terminated, .killed: PortStore.shared.show(L("Kapatıldı \(label)", "Stopped \(label)"))
                case .notPermitted: PortStore.shared.show(L("Bu süreci kapatma izni yok", "Not permitted to stop this process"))
                default: PortStore.shared.show(L("Süreç kapanmadı", "Process didn't stop"))
                }
                PortStore.shared.refresh()
            }
        }
    }

    func show(_ s: String) {
        toast = s
        Task { try? await Task.sleep(nanoseconds: 2_200_000_000); if toast == s { toast = nil } }
    }

    private func announce(_ it: PortItem) {
        guard notify else { return }
        let c = UNMutableNotificationContent()
        c.title = "\(it.cls.kind.name) :\(it.port)"
        c.body = L("\(it.title) başladı — http://localhost:\(it.port)", "\(it.title) started — http://localhost:\(it.port)")
        c.userInfo = ["url": it.localURL.absoluteString]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: it.id, content: c, trigger: nil))
    }

    // MARK: Ayarlar

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do { if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
            catch { show(L("Oturum açılışına eklenemedi", "Couldn't change login item")) }
            objectWillChange.send()
        }
    }

    func setLanguage(_ code: String) {
        UserDefaults.standard.set(code, forKey: "lang")
        Lang.isEnglish = code == "en"
        langVersion += 1
        items = items.map { var x = $0; x.cls = Classifier.classify(x.socket, x.details); return x }
    }
}

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let s = response.notification.request.content.userInfo["url"] as? String, let u = URL(string: s) {
            NSWorkspace.shared.open(u)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
