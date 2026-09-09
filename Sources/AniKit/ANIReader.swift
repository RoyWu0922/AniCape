import Foundation

private struct RiffChunk { let id: String; let body: Data }

private func chunks(in data: Data, start: Int) throws -> [RiffChunk] {
    var out: [RiffChunk] = []
    var off = start
    while off + 8 <= data.count {
        let id = String(decoding: data[off..<off + 4], as: UTF8.self)
        let len = data[off + 4..<off + 8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
        guard off + 8 + Int(len) <= data.count else { throw ANIError.truncated }
        // Data(a..<b) on this Foundation keeps the parent's absolute indices; re-base to 0
        // so downstream slicing (b[o..<o+4], chunk recursion) uses plain 0-based offsets.
        let body = Data(data[off + 8..<off + 8 + Int(len)])
        out.append(RiffChunk(id: id, body: body))
        off += 8 + Int(len) + (Int(len) % 2)   // chunk 内容按 2 字节对齐补零
    }
    return out
}

public enum ANIReader {
    public static func parse(url: URL) throws -> ParsedANI {
        let data = try Data(contentsOf: url)
        guard data.count >= 12, String(decoding: data[0..<4], as: UTF8.self) == "RIFF" else { throw ANIError.notRIFF }
        guard String(decoding: data[8..<12], as: UTF8.self) == "ACON" else { throw ANIError.notACON }
        var header: ANIHeader?
        var frames: [Data] = []
        var rates: [Int]?
        var seq: [Int]?
        for c in try chunks(in: data, start: 12) {
            switch c.id {
            case "anih":
                let b = c.body
                guard b.count >= 36 else { throw ANIError.truncated }
                let rd = { (o: Int) -> UInt32 in
                    b[o..<o + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
                }
                // anih 布局: cbSize(0) frames(4) steps(8) cx(16) cy(20) bitCount(24) planes(26) rate(28) flags(32)
                header = ANIHeader(declaredFrames: Int(rd(4)), defaultRateJiffies: Int(rd(28)),
                                   width: Int(rd(16)), height: Int(rd(20)))
            case "rate":
                guard c.body.count % 4 == 0 else { throw ANIError.truncated }
                rates = stride(from: 0, to: c.body.count, by: 4).map {
                    Int(c.body[$0..<$0 + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
                }
            case "seq ":
                guard c.body.count % 4 == 0 else { throw ANIError.truncated }
                seq = stride(from: 0, to: c.body.count, by: 4).map {
                    Int(c.body[$0..<$0 + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
                }
            case "LIST":
                guard c.body.count >= 4, String(decoding: c.body[0..<4], as: UTF8.self) == "fram" else { continue }
                for sub in try chunks(in: c.body, start: 4) where sub.id == "icon" {
                    frames.append(sub.body)
                }
            default:
                continue
            }
        }
        guard let header else { throw ANIError.truncated }
        guard !frames.isEmpty else { throw ANIError.noFrames }
        guard header.declaredFrames > 0 else { throw ANIError.invalidFrameCount }
        return ParsedANI(header: header, frameBodies: frames, rates: rates, seq: seq)
    }
}
