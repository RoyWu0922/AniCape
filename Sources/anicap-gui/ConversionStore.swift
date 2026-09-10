import Foundation
import Core
import CapeKit
import RoleKit

@MainActor
final class ConversionStore: ObservableObject {
    enum Phase: Equatable {
        case empty, analyzing, ready, converting
        case done(path: String, cursors: Int)
        case failed(String)
    }

    private enum Outcome {
        case done(path: String, cursors: Int, warnings: [String])
        case failed(String)
    }

    @Published private(set) var items: [ConversionItem] = []
    @Published private(set) var warnings: [String] = []
    @Published private(set) var phase: Phase = .empty
    @Published var assignments: [URL: String] = [:]
    @Published var excluded: Set<URL> = []
    @Published var name: String = ""
    @Published var author: String = "anicap"
    @Published var outputURL: URL?

    private var pathWasEdited = false

    // MARK: - 派生状态

    /// 会被写进 .cape 的光标数（0 → 转换按钮禁用）。
    var effectiveCount: Int {
        items.filter { item in
            guard item.cursor != nil, !excluded.contains(item.sourceURL) else { return false }
            return assignments[item.sourceURL] != nil || item.autoIdentifier != nil
        }.count
    }

    /// 指向同一槽位的 identifier 集合（GUI 高亮用）。
    var conflictingIdentifiers: Set<String> {
        var counts: [String: Int] = [:]
        for item in items {
            guard item.cursor != nil, !excluded.contains(item.sourceURL) else { continue }
            guard let id = assignments[item.sourceURL] ?? item.autoIdentifier else { continue }
            counts[id, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    /// 该行最终归属的槽位（nil = 不纳入）。
    func identifier(for item: ConversionItem) -> String? {
        assignments[item.sourceURL] ?? item.autoIdentifier
    }

    // MARK: - 用户动作

    /// 行内下拉：nil = 不纳入。
    func setAssignment(_ identifier: String?, for item: ConversionItem) {
        if let identifier {
            assignments[item.sourceURL] = identifier
            excluded.remove(item.sourceURL)
        } else {
            assignments.removeValue(forKey: item.sourceURL)
            if item.autoIdentifier != nil { excluded.insert(item.sourceURL) }
            else { excluded.remove(item.sourceURL) }
        }
    }

    /// 文件夹 → pack 语义；散装 .ani → 按文件名识别。累加 + 按 sourceURL 去重。
    func add(urls: [URL]) {
        var incoming: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles])) ?? []
                incoming.append(contentsOf: children)
                if name.isEmpty { name = url.lastPathComponent }
            } else {
                incoming.append(url)
                if name.isEmpty { name = url.deletingLastPathComponent().lastPathComponent }
            }
        }
        let known = Set(items.map { $0.sourceURL })
        let fresh = incoming.filter { !known.contains($0) && $0.pathExtension.lowercased() == "ani" }
        guard !fresh.isEmpty else { return }
        updateDefaultOutputPath()

        phase = .analyzing
        let existing = self.items
        Task {
            let analyzed = await Self.analyze(fresh)
            self.items = existing + analyzed
            self.phase = self.items.isEmpty ? .empty : .ready
        }
    }

    func setOutputURL(_ url: URL) {
        outputURL = url
        pathWasEdited = true
    }

    /// 名称变化时跟随默认路径——但仅在用户没手动改过路径时。
    func updateDefaultOutputPath() {
        guard !pathWasEdited else { return }
        let base = name.isEmpty ? "cape" : name
        outputURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent("\(base).cape")
    }

    func convert() {
        guard let outputURL else { return }
        phase = .converting
        let items = self.items, assignments = self.assignments, excluded = self.excluded
        let name = self.name.isEmpty ? "cape" : self.name, author = self.author
        Task {
            let outcome = await Self.perform(items: items, assignments: assignments,
                                             excluded: excluded, name: name,
                                             author: author, outputURL: outputURL)
            switch outcome {
            case .done(let path, let count, let warns):
                self.warnings = warns
                self.phase = .done(path: path, cursors: count)
            case .failed(let message):
                self.phase = .failed(message)      // 绝不在此路径显示成功
            }
        }
    }

    func clear() {
        items = []
        assignments = [:]
        excluded = []
        warnings = []
        name = ""
        pathWasEdited = false
        outputURL = nil
        phase = .empty
    }

    // MARK: - 后台执行（不阻塞主线程）

    nonisolated private static func analyze(_ urls: [URL]) async -> [ConversionItem] {
        await Task.detached(priority: .userInitiated) { Converter.plan(files: urls) }.value
    }

    nonisolated private static func perform(items: [ConversionItem], assignments: [URL: String],
                                            excluded: Set<URL>, name: String, author: String,
                                            outputURL: URL) async -> Outcome {
        await Task.detached(priority: .userInitiated) {
            do {
                let (doc, warns) = try Converter.assemble(items: items, assignments: assignments,
                                                          excluded: excluded, name: name, author: author)
                try CapeWriter.write(document: doc, to: outputURL)
                return Outcome.done(path: outputURL.path, cursors: doc.cursors.count, warnings: warns)
            } catch {
                return Outcome.failed("\(error)")
            }
        }.value
    }
}
