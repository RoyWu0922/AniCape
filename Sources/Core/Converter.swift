import Foundation
import AniKit
import CapeKit
import RoleKit

public struct PackResult {
    public let url: URL
    public let cursors: Int
    public let skipped: [String]
}

public enum Converter {
    public static func capeCursor(fromANI url: URL, identifier: String) throws -> CapeCursor {
        let parsed = try ANIReader.parse(url: url)
        let doc = try ANIDocumentBuilder.build(parsed: parsed)
        let first = doc.frames[0]
        var steps: [[UInt8]] = []
        steps.reserveCapacity(doc.displayIndices.count)
        for idx in doc.displayIndices { steps.append(doc.frames[idx].rgba) }
        return CapeCursor(identifier: identifier, frameDuration: doc.frameDuration,
                          frameWidthPx: first.width, frameHeightPx: first.height,
                          hotspotX: first.hotspotX, hotspotY: first.hotspotY, frames: steps)
    }

    public static func slug(_ s: String) -> String {
        let lowered = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let chars: [Character] = lowered.unicodeScalars.map { scalar in
            let v = Int(scalar.value)
            if (48...57).contains(v) || (97...122).contains(v) { return Character(String(scalar)) }
            return "-"
        }
        let parts = String(chars).split(separator: "-")
        let joined = parts.joined(separator: "-")
        return joined.isEmpty ? "cape" : joined
    }

    public static func pack(folder: URL, outURL: URL, author: String, name: String) throws -> PackResult {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                               options: [.skipsHiddenFiles])
        let anis = files.filter { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false else { return false }
            return url.pathExtension.lowercased() == "ani"
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var cursors: [String: CapeCursor] = [:]
        var skipped: [String] = []
        for url in anis {
            let base = url.deletingPathExtension().lastPathComponent
            guard let identifier = RoleMap.identifier(forFileName: base) else {
                skipped.append(url.lastPathComponent)
                continue
            }
            do {
                cursors[identifier] = try capeCursor(fromANI: url, identifier: identifier)
            } catch {
                skipped.append("\(url.lastPathComponent) (\(error))")
            }
        }
        let doc = CapeDocument(name: name, author: author,
                               identifier: "local.anicap.\(slug(folder.lastPathComponent))", cursors: cursors)
        try CapeWriter.write(document: doc, to: outURL)
        return PackResult(url: outURL, cursors: cursors.count, skipped: skipped)
    }
}
