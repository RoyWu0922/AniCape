import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onURLs: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cursorarrow.rays").font(.system(size: 34))
            Text("拖入 .ani 或文件夹").font(.title3)
            Text("也可以点这里选择").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                              style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { pick() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    if let url = await Self.fileURL(from: provider) { urls.append(url) }
                }
                onURLs(urls)
            }
            return true
        }
    }

    /// 本机 SDK 未导出 `loadDataRepresentation(forTypeIdentifier:)` 的 async 形式，
    /// 故用 continuation 包一层 completion-handler 版本（行为等价）。
    @MainActor private static func fileURL(from provider: NSItemProvider) async -> URL? {
        let data: Data? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data, let text = String(data: data, encoding: .utf8) else { return nil }
        return URL(string: text)
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK { onURLs(panel.urls) }
    }
}
