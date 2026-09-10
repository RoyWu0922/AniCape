import SwiftUI
import AppKit

struct BottomBarView: View {
    @ObservedObject var store: ConversionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("名称", text: $store.name)
                    .frame(width: 160)
                    .onChange(of: store.name) { _ in store.updateDefaultOutputPath() }
                TextField("作者", text: $store.author).frame(width: 140)
                Spacer()
                Button("转换") { store.convert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.effectiveCount == 0 || store.phase == .converting)
                Button("清空") { store.clear() }
                    .disabled(store.items.isEmpty)
            }
            HStack(spacing: 8) {
                Text("输出").foregroundStyle(.secondary)
                Text(store.outputURL?.path ?? "—")
                    .lineLimit(1).truncationMode(.middle)
                Button("选择…") { chooseOutput() }
            }
            statusLine
        }
        .padding(12)
    }

    @ViewBuilder private var statusLine: some View {
        switch store.phase {
        case .analyzing:
            Text("分析中…").font(.callout).foregroundStyle(.secondary)
        case .done(let path, let cursors):
            VStack(alignment: .leading, spacing: 4) {
                Text("✅ 已写出 \(cursors) 个光标 → \(path)").font(.callout)
                HStack {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    Button("用 Mousecape 打开") { openInMousecape(URL(fileURLWithPath: path)) }
                }
            }
        case .failed(let message):
            Text("❌ \(message)").font(.callout).foregroundStyle(.red)
        default:
            Text("有效光标 \(store.effectiveCount) 个")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func chooseOutput() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (store.name.isEmpty ? "cape" : store.name) + ".cape"
        if panel.runModal() == .OK, let url = panel.url { store.setOutputURL(url) }
    }

    private func openInMousecape(_ url: URL) {
        let app = URL(fileURLWithPath: "/Applications/Mousecape.app")
        guard FileManager.default.fileExists(atPath: app.path) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration())
    }
}
