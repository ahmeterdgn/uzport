import AppKit
import Carbon.HIToolbox
import SwiftUI
import UserNotifications
import PortCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notifications = NotificationHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // yalnızca menü çubuğu
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = notifications
        }
        Task { @MainActor in
            PortStore.shared.start()
            ProcessManager.shared.rescanProjects()
            if ProcessInfo.processInfo.environment["UZPORT_SCREENSHOT"] == nil { HotKey.shared.register() }
            await DemoMode.runIfRequested()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // UzPort'un başlattığı sunucular uygulamayla birlikte kapanır.
        MainActor.assumeIsolated { ProcessManager.shared.stopAll() }
    }

    // Log penceresi kapanınca uygulama kapanmasın.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct UzPortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = PortStore.shared
    @StateObject private var pm = ProcessManager.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(store).environmentObject(pm)
        } label: {
            MenuBarLabel(count: store.activeCount, managed: pm.servers.filter { $0.state.isAlive }.count)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(L("Loglar", "Logs"), id: "logs", for: UUID.self) { $id in
            LogWindow(serverID: id).environmentObject(pm)
        }
        .defaultSize(width: 820, height: 480)
    }
}

struct MenuBarLabel: View {
    let count: Int
    let managed: Int
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: count > 0 ? "dot.radiowaves.left.and.right" : "moon.zzz")
            if count > 0 { Text("\(count)").monospacedDigit() }
        }
    }
}

/// ⌃⌥P: paneli her yerden açan genel kısayol (yüzen pencere olarak).
@MainActor
final class HotKey {
    static let shared = HotKey()
    private var ref: EventHotKeyRef?
    private var panel: NSPanel?

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in HotKey.shared.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x555A5054), id: 1) // "UZPT"
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
    }

    func toggle() {
        if let p = panel, p.isVisible {
            p.orderOut(nil)
            return
        }
        let p = panel ?? makePanel()
        panel = p
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameTopLeftPoint(NSPoint(x: f.maxX - p.frame.width - 16, y: f.maxY - 8))
        }
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let host = NSHostingView(rootView: PanelView()
            .environmentObject(PortStore.shared)
            .environmentObject(ProcessManager.shared)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
        host.frame.size = NSSize(width: 452, height: 640)
        let p = KeyPanel(contentRect: host.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                         backing: .buffered, defer: false)
        p.contentView = host
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = true
        p.isMovableByWindowBackground = true
        return p
    }
}

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) } // Esc kapatır
}
