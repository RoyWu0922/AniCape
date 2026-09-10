import SwiftUI
import Core
import L10nKit

struct PreviewPaneView: View {
    let item: ConversionItem?
    @EnvironmentObject private var settings: LanguageSettings

    private var lang: Language { settings.language }

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
                Text(String(format: L10n.text(.previewCaption, lang),
                            cursor.frames.count, cursor.frameWidthPx, cursor.frameHeightPx,
                            cursor.hotspotX, cursor.hotspotY,
                            Int((cursor.frameDuration * 1000).rounded())))
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let item {
                Text(String(format: L10n.text(.noPreview, lang), item.fileName))
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.text(.selectToPreview, lang)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}
