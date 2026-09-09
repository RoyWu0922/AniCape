import Foundation

public enum ANIDocumentBuilder {
    public static func build(parsed: ParsedANI) throws -> ANIDocument {
        let images = try parsed.frameBodies.map { try CURDecoder.decode(miniCur: $0) }
        guard let first = images.first else { throw ANIError.noFrames }
        let w0 = first.width, h0 = first.height
        if let bad = images.enumerated().first(where: { $0.element.width != w0 || $0.element.height != h0 }) {
            throw ANIDocumentError.mismatchedFrameSize(bad.offset)
        }
        let indices: [Int]
        if let seq = parsed.seq {
            guard seq.allSatisfy({ $0 >= 0 && $0 < images.count }) else { throw ANIDocumentError.badSeq }
            indices = seq
        } else {
            indices = Array(0..<images.count)
        }
        guard indices.count <= 24 else { throw ANIDocumentError.tooManyFrames(indices.count) }
        let jiffies: Int
        if let rates = parsed.rates, !rates.isEmpty {
            jiffies = rates[0]          // 语料恒均匀；不均时取首值（已知限制，spec §10）
        } else {
            jiffies = parsed.header.defaultRateJiffies
        }
        return ANIDocument(frames: images, displayIndices: indices, frameDuration: Double(jiffies) / 60.0)
    }
}
