import SwiftUI
import Core
import RoleKit

struct ItemRowView: View {
    let item: ConversionItem
    @ObservedObject var store: ConversionStore

    private var isConflicting: Bool {
        guard let id = store.identifier(for: item) else { return false }
        return store.conflictingIdentifiers.contains(id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if isConflicting {
                    Text("与另一文件指向同一槽位：转换时后者覆盖前者")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            badge
            if case .error = item.status {
                EmptyView()
            } else {
                Picker("", selection: Binding(
                    get: { store.identifier(for: item) ?? "" },
                    set: { store.setAssignment($0.isEmpty ? nil : $0, for: item) })) {
                    Text("不纳入").tag("")
                    Divider()
                    ForEach(RoleMap.assignableRoles, id: \.identifier) { role in
                        Text("\(role.name) — \(role.identifier)").tag(role.identifier)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var thumbnail: some View {
        if let cursor = item.cursor, let image = CursorImages.firstImage(for: cursor) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "photo").frame(width: 28, height: 28).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        guard let cursor = item.cursor else { return "不可用" }
        return "\(cursor.frames.count) 帧 · \(cursor.frameWidthPx)×\(cursor.frameHeightPx)"
    }

    @ViewBuilder private var badge: some View {
        switch item.status {
        case .ready:
            Text("✅")
        case .needsAssignment(let reason):
            Text(reason == .noMacSlot ? "⚠️ 无 mac 槽" : "⚠️ 未识别")
                .font(.caption).foregroundStyle(.orange)
        case .error(let message):
            Text("❌").help(message)
        }
    }
}

struct ItemListView: View {
    @ObservedObject var store: ConversionStore
    // Ruling P3：selection 以 URL 为键（ConversionItem 非 Hashable，List 的 tag 必须 Hashable）。
    @Binding var selection: URL?

    var body: some View {
        List(selection: $selection) {
            ForEach(store.items, id: \.sourceURL) { item in
                ItemRowView(item: item, store: store).tag(item.sourceURL)
            }
        }
    }
}
