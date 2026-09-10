import SwiftUI
import AppKit
import Core

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
    @StateObject private var store = ConversionStore()
    // Ruling P3：以 URL 为选择键（ConversionItem 非 Hashable）。
    @State private var selection: URL?

    var body: some Scene {
        WindowGroup("anicap") {
            VStack(spacing: 0) {
                if store.items.isEmpty {
                    DropZoneView { store.add(urls: $0) }
                } else {
                    HSplitView {
                        ItemListView(store: store, selection: $selection)
                            .frame(minWidth: 380)
                        // Ruling P3：selection 是 URL?，须按 sourceURL 解析成 ConversionItem。
                        PreviewPaneView(item: store.items.first { $0.sourceURL == selection })
                            .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                Divider()
                BottomBarView(store: store)
            }
            .frame(minWidth: 720, minHeight: 460)
            .onAppear { store.updateDefaultOutputPath() }
            // 列表非空后整窗仍接收投放（spec §5「拖入是累加」），
            // 与空态的 DropZoneView 走同一个 store.add(urls:)。
            // 若同一次投放被内外两处都投递，store 在合并点按 sourceURL 去重，重复无害。
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                Task { store.add(urls: await DropReceiver.urls(from: providers)) }
                return true
            }
        }
    }
}
