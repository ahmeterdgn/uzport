import AppKit
import SwiftUI
import PortCore

/// Panelin üstündeki "Başlat" bölümü: son projeler ve aramayla tüm projeler.
struct LaunchSection: View {
    @EnvironmentObject var store: PortStore
    @EnvironmentObject var pm: ProcessManager
    @State private var showAll = false

    var matches: [Project] {
        let q = store.query.trimmingCharacters(in: .whitespaces).lowercased()
        let notRunning = pm.projects.filter { pm.server(for: $0) == nil }
        if !q.isEmpty {
            if UInt16(q) != nil { return [] }
            return notRunning.filter { $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q) || $0.kindName.lowercased().contains(q) }
        }
        if showAll { return notRunning }
        let recent = pm.recent.compactMap { r in notRunning.first { $0.path == r } }
        return Array((recent.isEmpty ? notRunning : recent).prefix(4))
    }

    var body: some View {
        let list = matches
        if !list.isEmpty || (store.query.isEmpty && !pm.projects.isEmpty) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(L("BAŞLAT", "LAUNCH")).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Theme.text3)
                    Text(store.query.isEmpty && !showAll && pm.recent.contains(where: { r in pm.projects.contains { $0.path == r } })
                         ? L("son kullanılanlar", "recent") : "\(list.count)")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.text3)
                        .padding(.horizontal, 5).background(Capsule().fill(Color.white.opacity(0.06)))
                    Spacer()
                    if store.query.isEmpty {
                        Button(showAll ? L("Daha az", "Less") : L("Tüm projeler (\(pm.projects.count))", "All projects (\(pm.projects.count))")) {
                            withAnimation(.easeOut(duration: 0.15)) { showAll.toggle() }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
                ForEach(list) { p in ProjectRow(project: p) }
            }
        }
    }
}

struct ProjectRow: View {
    @EnvironmentObject var pm: ProcessManager
    let project: Project
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
                Image(systemName: "folder.fill").font(.system(size: 14)).foregroundStyle(Theme.text3)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                HStack(spacing: 5) {
                    Chip(text: project.kindName, color: Theme.text2)
                    Text(project.defaultCommand?.command ?? "").font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Theme.text3).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if project.commands.count > 1 {
                Menu {
                    ForEach(project.commands) { c in
                        Button(c.command) { pm.start(project, c) }
                    }
                    Divider()
                    Button(L("Finder'da göster", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
                    }
                } label: {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.text3)
                        .frame(width: 20, height: 26)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(hover ? 1 : 0.5)
            }
            Button { pm.start(project) } label: {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 26)
                    .background(Capsule().fill(Theme.accentGradient))
                    .shadow(color: Theme.accent.opacity(hover ? 0.5 : 0.2), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .help(L("Başlat: \(project.defaultCommand?.command ?? "")", "Start: \(project.defaultCommand?.command ?? "")"))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(hover ? Color.white.opacity(0.05) : Color.white.opacity(0.015)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

/// UzPort'un başlattığı ama henüz port açmamış (başlıyor) ya da kapanmış sunucular.
struct ManagedRow: View {
    @EnvironmentObject var pm: ProcessManager
    @ObservedObject var server: ManagedServer
    @Environment(\.openWindow) private var openWindow

    var crashed: Bool { if case .exited(let c) = server.state { return c != 0 } else { return false } }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill((crashed ? Theme.red : Theme.accent).opacity(0.14))
                if server.state.isAlive {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: crashed ? "exclamationmark.triangle.fill" : "stop.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(crashed ? Theme.red : Theme.text3)
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(statusText).font(.system(size: 10.5, weight: .bold)).foregroundStyle(crashed ? Theme.red : Theme.text3)
                }
                Text(server.lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? server.command.command)
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 4)
            IconButton(symbol: "text.alignleft", help: L("Loglar", "Logs")) { openLogs(server, openWindow) }
            if server.state.isAlive {
                IconButton(symbol: "stop.fill", tint: Theme.red, help: L("Durdur", "Stop")) { pm.stop(server) }
            } else {
                IconButton(symbol: "arrow.clockwise", help: L("Yeniden başlat", "Restart")) { pm.restart(server) }
                IconButton(symbol: "xmark", help: L("Listeden kaldır", "Dismiss")) { pm.remove(server) }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill((crashed ? Theme.red : Color.white).opacity(crashed ? 0.06 : 0.022)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(crashed ? Theme.red.opacity(0.35) : Theme.stroke, lineWidth: 1))
    }

    var statusText: String {
        switch server.state {
        case .starting: return L("başlatılıyor…", "starting…")
        case .running: return L("çalışıyor", "running")
        case .exited(let c): return c == 0 ? L("bitti", "finished") : L("çöktü · kod \(c)", "crashed · code \(c)")
        case .stopped: return L("durduruldu", "stopped")
        }
    }
}

@MainActor
func openLogs(_ s: ManagedServer, _ openWindow: OpenWindowAction) {
    NSApp.activate(ignoringOtherApps: true)
    openWindow(id: "logs", value: s.id)
}

// MARK: - Log penceresi

struct LogWindow: View {
    @EnvironmentObject var pm: ProcessManager
    let serverID: UUID?

    var body: some View {
        if let id = serverID, let s = pm.servers.first(where: { $0.id == id }) {
            LogView(server: s)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "text.alignleft").font(.system(size: 28)).foregroundStyle(Theme.text3)
                Text(L("Bu sunucu artık listede değil", "This server is no longer listed")).foregroundStyle(Theme.text2)
            }
            .frame(minWidth: 520, minHeight: 300)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
    }
}

struct LogView: View {
    @EnvironmentObject var pm: ProcessManager
    @ObservedObject var server: ManagedServer
    @State private var filter = ""
    @State private var follow = true

    var shown: [(Int, String)] {
        let all = Array(server.lines.enumerated())
        guard !filter.isEmpty else { return all.map { ($0.offset, $0.element) } }
        return all.filter { $0.element.localizedCaseInsensitiveContains(filter) }.map { ($0.offset, $0.element) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(server.state.isAlive ? Theme.green : (server.state == .stopped ? Theme.text3 : Theme.red)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(server.title).font(Theme.rounded(14, .bold)).foregroundStyle(Theme.text)
                    Text(server.command.command).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text3)
                }
                Spacer()
                if let u = server.detectedURL {
                    Button { NSWorkspace.shared.open(u) } label: {
                        Label(u.absoluteString, systemImage: "safari").font(.system(size: 11.5, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                }
                TextField("", text: $filter, prompt: Text(L("Loglarda ara", "Filter logs")).foregroundColor(Theme.text3))
                    .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 8).frame(width: 170, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))
                Toggle(L("Takip et", "Follow"), isOn: $follow).toggleStyle(.checkbox).font(.system(size: 11.5))
                IconButton(symbol: "doc.on.doc", help: L("Tümünü kopyala", "Copy all")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(server.lines.joined(separator: "\n"), forType: .string)
                }
                IconButton(symbol: "trash", help: L("Temizle", "Clear")) { server.lines.removeAll() }
                if server.state.isAlive {
                    IconButton(symbol: "arrow.clockwise", help: L("Yeniden başlat", "Restart")) { pm.restart(server) }
                    IconButton(symbol: "stop.fill", tint: Theme.red, help: L("Durdur", "Stop")) { pm.stop(server) }
                } else {
                    IconButton(symbol: "play.fill", tint: Theme.green, help: L("Yeniden başlat", "Restart")) { pm.restart(server) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.2))
            Rectangle().fill(Theme.stroke).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(shown, id: \.0) { i, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(color(line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: server.lines.count) { _ in
                    if follow, let last = shown.last { proxy.scrollTo(last.0, anchor: .bottom) }
                }
                .onAppear { if let last = shown.last { proxy.scrollTo(last.0, anchor: .bottom) } }
            }
        }
        .frame(minWidth: 640, minHeight: 360)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .navigationTitle(L("\(server.title) — Loglar", "\(server.title) — Logs"))
    }

    func color(_ l: String) -> Color {
        let s = l.lowercased()
        if s.hasPrefix("$ ") { return Theme.accent }
        if s.contains("error") || s.contains("hata") || s.contains("failed") || s.hasPrefix("✕") { return Theme.red }
        if s.contains("warn") { return Theme.amber }
        if s.contains("ready") || s.contains("local:") || s.contains("listening") || s.contains("started") { return Theme.green }
        return Theme.text2
    }
}
