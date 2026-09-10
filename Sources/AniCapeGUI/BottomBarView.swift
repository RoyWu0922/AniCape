import SwiftUI
import AppKit
import L10nKit

struct BottomBarView: View {
    @ObservedObject var store: ConversionStore
    @EnvironmentObject private var settings: LanguageSettings

    private var lang: Language { settings.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField(L10n.text(.nameField, lang), text: $store.name)
                    .frame(width: 160)
                    .onChange(of: store.name) { _ in store.updateDefaultOutputPath() }
                TextField(L10n.text(.authorField, lang), text: $store.author).frame(width: 140)
                Spacer()
                Button(L10n.text(.convert, lang)) { store.convert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.effectiveCount == 0 || store.phase == .converting)
                Button(L10n.text(.clear, lang)) { store.clear() }
                    .disabled(store.items.isEmpty)
                languagePicker
            }
            HStack(spacing: 8) {
                Text(L10n.text(.outputLabel, lang)).foregroundStyle(.secondary)
                Text(store.outputURL?.path ?? "—")
                    .lineLimit(1).truncationMode(.middle)
                Button(L10n.text(.chooseOutput, lang)) { chooseOutput() }
            }
            statusLine
            conflictLines
        }
        .padding(12)
    }

    /// 分段控件里用语言自己的名字（中文 / English），不是翻译后的名字——
    /// 看不懂当前语言的人才找得到自己那一项。
    private var languagePicker: some View {
        Picker(L10n.text(.languageLabel, lang), selection: $settings.language) {
            ForEach(Language.allCases) { language in
                Text(language.selfName).tag(language)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 150)
        .help(L10n.text(.languageLabel, lang))
    }

    /// 预览态的冲突说明文字（spec §5：无需先点转换即可看到冲突）。
    @ViewBuilder private var conflictLines: some View {
        ForEach(store.conflictMessages(lang), id: \.self) { message in
            Text(message)
                .font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch store.phase {
        case .analyzing:
            Text(L10n.text(.analyzing, lang)).font(.callout).foregroundStyle(.secondary)
        case .done(let path, let cursors):
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: L10n.text(.success, lang), cursors, path)).font(.callout)
                HStack {
                    Button(L10n.text(.revealFinder, lang)) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    Button(L10n.text(.openMousecape, lang)) { openInMousecape(URL(fileURLWithPath: path)) }
                }
            }
        case .failed(let message):
            Text(String(format: L10n.text(.failed, lang), message))
                .font(.callout).foregroundStyle(.red)
        default:
            Text(String(format: L10n.text(.idleCount, lang), store.effectiveCount))
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
