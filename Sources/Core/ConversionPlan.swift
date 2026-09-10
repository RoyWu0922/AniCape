import Foundation
import AniKit
import CapeKit
import RoleKit

/// 未被自动纳入的原因。
public enum SkipReason: Equatable {
    case noMacSlot      // 命中 RoleMap.skippedRoleNames（手写/候选/位置选择/个人选择 …）
    case unrecognized   // 文件名不含任何已知角色名
}

public enum ItemStatus: Equatable {
    case ready(String)                 // 自动识别的 identifier
    case needsAssignment(SkipReason)   // 可解码但无角色，默认不纳入
    case error(String)                 // 解析/解码失败
}

public struct ConversionItem {
    public let sourceURL: URL
    public let fileName: String
    public let displayName: String
    public let status: ItemStatus
    public let cursor: CapeCursor?     // 解码成功则非 nil（identifier 为占位，assemble 时重标）

    public init(sourceURL: URL, fileName: String, displayName: String,
                status: ItemStatus, cursor: CapeCursor?) {
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.displayName = displayName
        self.status = status
        self.cursor = cursor
    }

    public var autoIdentifier: String? {
        if case .ready(let id) = status { return id }
        return nil
    }
}

public enum ConversionError: Error, Equatable {
    case noCursors
}

extension Converter {
    /// 逐文件分析（不写盘）。忽略目录与非 .ani；按 fileName 升序，与 CLI pack 一致。
    /// 每个文件只解码一次，结果挂在 item.cursor 上供预览与 assemble 复用。
    public static func plan(files: [URL]) -> [ConversionItem] {
        let anis = files.filter { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false else { return false }
            return url.pathExtension.lowercased() == "ani"
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        return anis.map { url in
            let fileName = url.lastPathComponent
            let base = url.deletingPathExtension().lastPathComponent
            var status: ItemStatus
            if RoleMap.skippedRoleNames.contains(base) {
                status = .needsAssignment(.noMacSlot)
            } else if let id = RoleMap.identifier(forFileName: base) {
                status = .ready(id)
            } else {
                status = .needsAssignment(.unrecognized)
            }
            var cursor: CapeCursor?
            do {
                cursor = try Converter.capeCursor(fromANI: url, identifier: "local.anicap.pending")
            } catch {
                status = .error("\(error)")      // 解码失败优先于 ready/needsAssignment
            }
            return ConversionItem(sourceURL: url, fileName: fileName, displayName: base,
                                  status: status, cursor: cursor)
        }
    }

    /// 非递归枚举文件夹**直接子项**（同 pack），再走 plan(files:)。
    public static func plan(folder: URL) throws -> [ConversionItem] {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return plan(files: files)
    }

    /// 组装文档：套用手动指派与排除，做同槽冲突仲裁（恒按文件名升序 last-wins）；空结果抛 .noCursors。
    public static func assemble(items: [ConversionItem],
                                assignments: [URL: String],
                                excluded: Set<URL>,
                                name: String,
                                author: String) throws -> (document: CapeDocument, warnings: [String]) {
        var cursors: [String: CapeCursor] = [:]
        var owner: [String: String] = [:]        // identifier → 当前占用的文件名
        var warnings: [String] = []

        for item in items.sorted(by: { $0.fileName < $1.fileName }) {
            guard let cursor = item.cursor, !excluded.contains(item.sourceURL) else { continue }
            guard let identifier = assignments[item.sourceURL] ?? item.autoIdentifier else { continue }
            if let previous = owner[identifier] {
                warnings.append("\(item.fileName) 覆盖 \(previous) → \(identifier)")
            }
            owner[identifier] = item.fileName
            cursors[identifier] = CapeCursor(identifier: identifier,
                                             frameDuration: cursor.frameDuration,
                                             frameWidthPx: cursor.frameWidthPx,
                                             frameHeightPx: cursor.frameHeightPx,
                                             hotspotX: cursor.hotspotX,
                                             hotspotY: cursor.hotspotY,
                                             frames: cursor.frames)
        }

        guard !cursors.isEmpty else { throw ConversionError.noCursors }
        let doc = CapeDocument(name: name, author: author,
                               identifier: "local.anicap.\(slug(name))", cursors: cursors)
        return (doc, warnings)
    }
}
