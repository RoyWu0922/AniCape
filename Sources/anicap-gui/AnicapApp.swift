import SwiftUI
import AppKit

/// 无 .app bundle 时（`make gui` / 直接跑二进制）必须显式设置激活策略，
/// 否则没有菜单栏、窗口也拿不到正常焦点。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AnicapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("anicap") {
            VStack(spacing: 12) {
                Text("anicap GUI 探针").font(.title2)
                Text("看到这个窗口且菜单栏出现 anicap，探针即通过。")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 420, height: 200)
        }
        .windowResizability(.contentSize)
    }
}
