import AppKit
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
            await DemoMode.runIfRequested()
        }
    }
}

@main
struct UzPortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = PortStore.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(store)
        } label: {
            MenuBarLabel(count: store.activeCount)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let count: Int
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: count > 0 ? "dot.radiowaves.left.and.right" : "moon.zzz")
            if count > 0 { Text("\(count)").monospacedDigit() }
        }
    }
}
