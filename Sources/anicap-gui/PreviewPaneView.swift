import SwiftUI
import Core

struct PreviewPaneView: View {
    let item: ConversionItem?

    var body: some View {
        VStack(spacing: 10) {
            if let item, let cursor = item.cursor {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor))
                    AnimatedCursorView(cursor: cursor)
                        .frame(maxWidth: 180, maxHeight: 180)
                        .padding(12)
                }
                .frame(height: 200)
                Text(item.fileName).font(.headline)
                Text("\(cursor.frames.count) 帧 · \(cursor.frameWidthPx)×\(cursor.frameHeightPx) · 热点 (\(cursor.hotspotX), \(cursor.hotspotY)) · \(Int((cursor.frameDuration * 1000).rounded()))ms/帧")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let item {
                Text("无法预览：\(item.fileName)").foregroundStyle(.secondary)
            } else {
                Text("选中一行查看预览").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}
