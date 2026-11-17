import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import PortCore

struct PanelView: View {
    @EnvironmentObject var store: PortStore
    @EnvironmentObject var pm: ProcessManager
    @State private var contentHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            Header()
            SearchBar()
            Rectangle().fill(Theme.stroke).frame(height: 1)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    PortLookup()
                    let dev = store.visible(.dev)
                    let pending = pm.servers.filter { s in !store.items.contains { $0.managedID == s.id } }
                    if !pending.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(pending) { s in ManagedRow(server: s) }
                        }
                    }
                    if dev.isEmpty && pending.isEmpty && store.query.isEmpty && pm.projects.isEmpty {
                        EmptyDev()
                    }
                    ForEach(PortCategory.allCases, id: \.self) { c in
                        let list = store.visible(c)
                        if !list.isEmpty {
                            SectionView(category: c, items: list)
                        }
                        if c == .dev { LaunchSection() }
                    }
                }
                .padding(12)
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                })
            }
            // Menü çubuğu penceresinde ScrollView kendi yüksekliğini bilemez: içeriğe göre ayarla.
            .frame(height: min(max(contentHeight, 80), 540))
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            Footer()
        }
        .frame(width: 452)
        .background(NightSky())
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                Text(t)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.card))
                    .overlay(Capsule().strokeBorder(Theme.strokeHi, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .id(store.langVersion)
        .preferredColorScheme(.dark)
    }
}

struct Header: View {
    @EnvironmentObject var store: PortStore

    var body: some View {
        HStack(spacing: 9) {
            AppLogo(size: 22)
            Text("UzPort").font(Theme.rounded(16, .bold)).foregroundStyle(Theme.text)
            Chip(text: L("\(store.activeCount) aktif", "\(store.activeCount) active"), symbol: "dot.radiowaves.left.and.right",
                 color: store.activeCount > 0 ? Theme.green : Theme.text3)
            Spacer()
            IconButton(symbol: "arrow.clockwise", help: L("Yenile", "Refresh")) { store.refresh() }
            SettingsMenu()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct SettingsMenu: View {
    @EnvironmentObject var store: PortStore
    var body: some View {
        Menu {
            Toggle(L("Uygulamaları göster", "Show apps"), isOn: $store.showApps)
            Toggle(L("macOS sistem portlarını göster", "Show macOS system ports"), isOn: $store.showSystem)
            Toggle(L("Yeni sunucu başlayınca bildir", "Notify when a dev server starts"), isOn: $store.notify)
            Toggle(L("Girişte başlat", "Launch at login"), isOn: Binding(get: { store.launchAtLogin }, set: { store.launchAtLogin = $0 }))
            Toggle(L("Çöken sunucuyu yeniden başlat", "Auto-restart crashed servers"), isOn: $store.autoRestart)
            Divider()
            Menu(L("Proje klasörleri", "Project folders")) {
                ForEach(ProcessManager.shared.roots, id: \.self) { r in
                    Button(L("Kaldır: ", "Remove: ") + (r as NSString).abbreviatingWithTildeInPath) {
                        ProcessManager.shared.roots.removeAll { $0 == r }
                    }
                }
                Divider()
                Button(L("Klasör ekle…", "Add folder…")) { addProjectFolder() }
                Button(L("Projeleri yeniden tara", "Rescan projects")) { ProcessManager.shared.rescanProjects() }
            }
            Text(L("Kısayol: ⌃⌥P paneli açar", "Shortcut: ⌃⌥P opens the panel"))
            Divider()
            Picker(L("Dil", "Language"), selection: Binding(get: { Lang.code }, set: { store.setLanguage($0) })) {
                Text("Türkçe").tag("tr")
                Text("English").tag("en")
            }
            Divider()
            Button(L("uzmoon.com", "uzmoon.com")) { NSWorkspace.shared.open(URL(string: "https://uzmoon.com")!) }
            Button(L("UzPort'tan çık", "Quit UzPort")) { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text2)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct SearchBar: View {
    @EnvironmentObject var store: PortStore
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.text3)
            TextField("", text: $store.query, prompt: Text(L("Ara ya da port yaz (ör. 3000)", "Search or type a port (e.g. 3000)")).foregroundColor(Theme.text3))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text)
                .focused($focused)
            if !store.query.isEmpty {
                Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text3) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

/// "3000 kimde?" — aranan port doluysa sahibini ve boşaltma düğmesini, boşsa onayı gösterir.
struct PortLookup: View {
    @EnvironmentObject var store: PortStore

    var body: some View {
        if let p = store.queriedPort {
            let owner = store.items.first { $0.port == p }
            HStack(spacing: 10) {
                Image(systemName: owner == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(owner == nil ? Theme.green : Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(owner == nil ? L("\(p) numaralı port boş", "Port \(p) is free")
                                      : L("\(p) numaralı portu \(owner!.title) kullanıyor", "Port \(p) is used by \(owner!.title)"))
                        .font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.text)
                    Text(owner.map { "\($0.cls.kind.name) · PID \($0.pid)" } ?? L("Sunucunu bu portta başlatabilirsin.", "You can start your server on this port."))
                        .font(.system(size: 11)).foregroundStyle(Theme.text2)
                }
                Spacer()
                if let o = owner, o.canKill {
                    Button { store.kill(o) } label: {
                        Text(store.armedKill == o.id ? L("Emin misin?", "Sure?") : L("Portu boşalt", "Free port"))
                            .font(.system(size: 11.5, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(height: 28)
                            .background(Capsule().fill(store.armedKill == o.id ? Theme.red : Theme.amber.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((owner == nil ? Theme.green : Theme.amber).opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder((owner == nil ? Theme.green : Theme.amber).opacity(0.25), lineWidth: 1))
        }
    }
}

struct EmptyDev: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 22)).foregroundStyle(Theme.accentGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Çalışan geliştirme sunucusu yok", "No dev servers running")).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.text)
                Text(L("npm run dev, php artisan serve… başlattığın an burada görünür.", "Start npm run dev, php artisan serve… and it shows up here instantly."))
                    .font(.system(size: 11)).foregroundStyle(Theme.text2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct SectionView: View {
    let category: PortCategory
    let items: [PortItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(category.title.uppercased(with: Lang.locale))
                    .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Theme.text3)
                Text("\(items.count)").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.text3)
                    .padding(.horizontal, 5).background(Capsule().fill(Color.white.opacity(0.06)))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
            ForEach(items) { it in PortRow(item: it) }
        }
    }
}

struct PortRow: View {
    @EnvironmentObject var store: PortStore
    @EnvironmentObject var pm: ProcessManager
    @Environment(\.openWindow) private var openWindow
    let item: PortItem
    var managed: ManagedServer? { item.managedID.flatMap { id in pm.servers.first { $0.id == id } } }
    @State private var hover = false
    @State private var showQR = false

    var probe: ProbeResult? { store.probes[item.id] }
    var kindColor: Color { Color(hex: item.cls.kind.color) }
    var isDevLike: Bool { [.dev, .services, .docker].contains(item.cls.category) }

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(":\(String(item.port))")
                        .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isDevLike ? Theme.text : Theme.text2)
                    if !item.extraPorts.isEmpty {
                        Text("+\(item.extraPorts.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.text3)
                            .help(item.extraPorts.map { ":\($0)" }.joined(separator: " "))
                    }
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let s = probe?.status, isDevLike {
                        Circle().fill(s < 400 ? Theme.green : (s < 500 ? Theme.amber : Theme.red)).frame(width: 6, height: 6)
                            .help("HTTP \(s)")
                    }
                }
                HStack(spacing: 5) {
                    Chip(text: item.dockerImage ?? item.cls.kind.name, color: kindColor)
                    if managed != nil {
                        Chip(text: "UzPort", symbol: "play.fill", color: Theme.accent).help(L("UzPort tarafından başlatıldı", "Started by UzPort"))
                    }
                    Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 4)
            if hover || store.armedKill == item.id || showQR {
                actions.transition(.opacity)
            } else if let mem = item.details?.residentBytes, mem > 0, isDevLike {
                Text(Fmt.bytes(mem)).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Theme.text3).monospacedDigit()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(hover ? Color.white.opacity(0.06) : Color.white.opacity(0.022)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(hover ? Theme.strokeHi : Theme.stroke, lineWidth: 1))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .onTapGesture { store.open(item) }
        .contextMenu { menu }
        .help(item.details?.commandLine ?? "")
    }

    var subtitle: String {
        var parts: [String] = []
        if let t = probe?.pageTitle, t != item.title { parts.append(t) }
        if let d = item.details?.startDate { parts.append(Fmt.ago(d)) }
        if item.cls.category == .system || item.cls.category == .apps { parts.append(item.details?.name ?? "") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(kindColor.opacity(0.16))
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(kindColor.opacity(0.28), lineWidth: 1)
            if let f = probe?.favicon {
                Image(nsImage: f).resizable().interpolation(.high).aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
            } else if item.cls.category == .apps, let path = item.details?.path, let r = path.range(of: ".app/") {
                Image(nsImage: NSWorkspace.shared.icon(forFile: String(path[..<r.lowerBound]) + ".app"))
                    .resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: item.cls.kind.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(kindColor)
            }
        }
        .frame(width: 34, height: 34)
    }

    var actions: some View {
        HStack(spacing: 0) {
            if item.cls.kind.opensInBrowser || probe?.status != nil {
                IconButton(symbol: "safari", help: L("Tarayıcıda aç", "Open in browser")) { store.open(item) }
                IconButton(symbol: "doc.on.doc", help: L("Adresi kopyala", "Copy URL")) { store.copyURL(item) }
                IconButton(symbol: "qrcode", help: L("Telefonda aç (QR)", "Open on phone (QR)")) { showQR.toggle() }
                    .popover(isPresented: $showQR, arrowEdge: .bottom) { QRCard(item: item) }
            }
            if let m = managed {
                IconButton(symbol: "text.alignleft", help: L("Loglar", "Logs")) { openLogs(m, openWindow) }
                IconButton(symbol: "arrow.clockwise", help: L("Yeniden başlat", "Restart")) { pm.restart(m) }
                IconButton(symbol: "stop.fill", tint: Theme.red, help: L("Durdur", "Stop")) { pm.stop(m) }
            } else if item.cls.projectPath != nil {
                IconButton(symbol: "folder", help: L("Klasörü göster", "Show folder")) { store.reveal(item) }
            }
            if item.canKill && managed == nil {
                Button { store.kill(item) } label: {
                    Group {
                        if store.armedKill == item.id {
                            Text(L("Kapat", "Stop")).font(.system(size: 10.5, weight: .bold)).padding(.horizontal, 8)
                        } else {
                            Image(systemName: "xmark").font(.system(size: 10.5, weight: .bold)).frame(width: 26)
                        }
                    }
                    .foregroundStyle(store.armedKill == item.id ? .white : Theme.red)
                    .frame(height: 24)
                    .background(Capsule().fill(store.armedKill == item.id ? Theme.red : Theme.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help(L("Süreci kapat (iki kez tıkla)", "Stop process (click twice)"))
                .padding(.leading, 3)
            }
        }
    }

    @ViewBuilder var menu: some View {
        if item.cls.kind.opensInBrowser || probe?.status != nil {
            Button(L("Tarayıcıda aç", "Open in browser")) { store.open(item) }
            Button(L("Adresi kopyala", "Copy URL")) { store.copyURL(item) }
            Button(L("Ağ adresini kopyala (\(store.lan ?? "-"))", "Copy network URL (\(store.lan ?? "-"))")) { store.copyURL(item, lan: true) }
        }
        if item.cls.projectPath != nil {
            Divider()
            Button(L("Finder'da göster", "Show in Finder")) { store.reveal(item) }
            if let e = store.editorName { Button(L("\(e) ile aç", "Open in \(e)")) { store.openIn(item, apps: PortStore.editors) } }
            Button(L("Terminalde aç", "Open in Terminal")) { store.openIn(item, apps: PortStore.terminals) }
        }
        Divider()
        Button(L("PID \(item.pid) kopyala", "Copy PID \(item.pid)")) {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString("\(item.pid)", forType: .string)
        }
        if let c = item.details?.commandLine, !c.isEmpty {
            Button(L("Komutu kopyala", "Copy command")) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(c, forType: .string)
            }
        }
        if item.canKill {
            Divider()
            Button(L("Süreci kapat", "Stop process"), role: .destructive) { store.armedKill = item.id; store.kill(item) }
        }
    }
}

struct QRCard: View {
    @EnvironmentObject var store: PortStore
    let item: PortItem

    var url: String { "http://\(store.lan ?? "localhost"):\(item.port)" }

    var body: some View {
        VStack(spacing: 10) {
            if let img = qr(url) {
                Image(nsImage: img).interpolation(.none).resizable().frame(width: 180, height: 180)
                    .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(.white))
            }
            Text(url).font(.system(size: 12, weight: .semibold, design: .monospaced)).textSelection(.enabled)
            if item.socket.isLoopbackOnly {
                Label(L("Sunucu yalnızca bu Mac'i dinliyor; telefondan açılmaz. Vite için --host, Next için -H 0.0.0.0 kullan.",
                        "This server only listens on this Mac, so phones can't reach it. Use --host (Vite) or -H 0.0.0.0 (Next)."),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(Theme.amber).frame(width: 220)
            } else {
                Text(L("Telefonun aynı Wi-Fi ağında olmalı.", "Your phone must be on the same Wi-Fi."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    func qr(_ s: String) -> NSImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let rep = NSCIImageRep(ciImage: out)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}

struct Footer: View {
    @EnvironmentObject var store: PortStore
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.text3)
            Text(store.lan ?? L("Ağ yok", "No network")).font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.text3).textSelection(.enabled)
            Spacer()
            UzmoonCredit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.2))
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }
}

enum Fmt {
    static func bytes(_ n: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var v = Double(n)
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? "\(n) B" : String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, units[i])
    }

    static func ago(_ d: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(d)))
        if s < 60 { return L("az önce", "just now") }
        if s < 3600 { return L("\(s / 60) dk", "\(s / 60)m") }
        if s < 86400 { return L("\(s / 3600) sa \((s % 3600) / 60) dk", "\(s / 3600)h \((s % 3600) / 60)m") }
        return L("\(s / 86400) gün", "\(s / 86400)d")
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

@MainActor
func addProjectFolder() {
    NSApp.activate(ignoringOtherApps: true)
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.canChooseFiles = false
    p.allowsMultipleSelection = true
    p.prompt = L("Ekle", "Add")
    p.message = L("UzPort bu klasörlerdeki projeleri bulup başlatabilir.", "UzPort will find and launch projects in these folders.")
    if p.runModal() == .OK {
        let new = p.urls.map(\.path).filter { !ProcessManager.shared.roots.contains($0) }
        ProcessManager.shared.roots += new
    }
}
