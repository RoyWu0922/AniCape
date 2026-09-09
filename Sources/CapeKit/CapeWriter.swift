import Foundation
import AppKit

public enum CapeWriter {
    public static func data(for cursor: CapeCursor) throws -> Data {
        let w = cursor.frameWidthPx, h = cursor.frameHeightPx
        guard !cursor.frames.isEmpty, w > 0, h > 0 else { throw CapeError.invalidCursor }
        for f in cursor.frames where f.count != w * h * 4 { throw CapeError.invalidCursor }
        let stripH = h * cursor.frames.count
        var strip = [UInt8](repeating: 0, count: w * stripH * 4)
        for (step, frame) in cursor.frames.enumerated() {
            strip.replaceSubrange((step * h * w * 4)..<((step + 1) * h * w * 4), with: frame)
        }
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: stripH,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)
        else { throw CapeError.tiffEncodeFailed }
        strip.withUnsafeBytes {
            rep.bitmapData!.update(from: $0.bindMemory(to: UInt8.self).baseAddress!, count: strip.count)
        }
        guard let tiff = rep.tiffRepresentation(using: .lzw, factor: 1.0) else { throw CapeError.tiffEncodeFailed }
        return tiff
    }

    public static func write(document: CapeDocument, to url: URL) throws {
        var tiffs: [String: Data] = [:]
        for (id, cur) in document.cursors { tiffs[id] = try data(for: cur) }
        let data = try CapeEnvelope.plistData(cape: document, tiff: tiffs)
        try data.write(to: url, options: .atomic)
    }
}
