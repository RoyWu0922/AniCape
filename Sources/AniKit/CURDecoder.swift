import Foundation

public enum CURError: Error, Equatable {
    case shortHeader, unsupportedType(Int), notBitmap(Int), unsupportedBPP(Int), unsupportedCompression(Int), corrupt
}

public struct CURImage {
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]        // 行主序 RGBA，顶行在前，count = w*h*4
    public let hotspotX: Int
    public let hotspotY: Int
    public init(width: Int, height: Int, rgba: [UInt8], hotspotX: Int, hotspotY: Int) {
        self.width = width; self.height = height; self.rgba = rgba
        self.hotspotX = hotspotX; self.hotspotY = hotspotY
    }
}

private func u16(_ d: Data, _ o: Int) -> Int {
    Int(d[o..<o + 2].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian)
}
private func u32(_ d: Data, _ o: Int) -> Int {
    Int(d[o..<o + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian)
}
private func i32(_ d: Data, _ o: Int) -> Int {
    Int(d[o..<o + 4].withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }.littleEndian)
}

public enum CURDecoder {
    public static func decode(miniCur: Data) throws -> CURImage {
        guard miniCur.count >= 22 else { throw CURError.shortHeader }
        let type = u16(miniCur, 2)
        guard type == 2 else { throw CURError.unsupportedType(type) }
        let hx = u16(miniCur, 10); let hy = u16(miniCur, 12)
        let imageOffset = u32(miniCur, 18)
        guard imageOffset + 40 <= miniCur.count else { throw CURError.corrupt }
        let img = Data(miniCur[imageOffset...])
        let biSize = u32(img, 0)
        guard biSize == 40 else { throw CURError.notBitmap(biSize) }
        let width = i32(img, 4)
        let rawHeight = i32(img, 8)
        let height = abs(rawHeight); let topDown = rawHeight < 0
        let bpp = u16(img, 14)
        let compression = u32(img, 16)
        let clrUsed = u32(img, 32)
        guard width > 0, height > 0, width <= 1024, height <= 2048 else { throw CURError.corrupt }
        guard compression == 0 else { throw CURError.unsupportedCompression(compression) }
        guard [8, 24, 32].contains(bpp) else { throw CURError.unsupportedBPP(bpp) }
        guard height % 2 == 0 else { throw CURError.corrupt }
        let frameH = height / 2     // XOR 高（AND 占另一半）

        var pos = 40
        var palette: [(UInt8, UInt8, UInt8)] = []
        if bpp <= 8 {
            let n = clrUsed > 0 ? clrUsed : (1 << bpp)
            guard pos + n * 4 <= img.count else { throw CURError.corrupt }
            for _ in 0..<n { palette.append((img[pos + 2], img[pos + 1], img[pos])); pos += 4 } // BGRX → RGB
        }
        let xorRowBytes = ((width * bpp + 31) / 32) * 4
        let xorBytes = xorRowBytes * frameH
        guard pos + xorBytes <= img.count else { throw CURError.corrupt }
        let xor = Array(img[pos..<pos + xorBytes]); pos += xorBytes
        let maskRowBytes = ((width + 31) / 32) * 4
        let maskBytes = maskRowBytes * frameH
        guard pos + maskBytes <= img.count else { throw CURError.corrupt }
        let and = Array(img[pos..<pos + maskBytes])

        var rgba = [UInt8](repeating: 0, count: width * frameH * 4)
        for yy in 0..<frameH {
            let xorRow = topDown ? yy : (frameH - 1 - yy)   // XOR 的存储行
            let andRow = frameH - 1 - yy                    // AND 与 XOR 同自下而上存储
            for x in 0..<width {
                let out = (yy * width + x) * 4
                let bit = and[andRow * maskRowBytes + x / 8] & UInt8(0x80 >> (x % 8))
                if bit != 0 { continue }                    // AND=1 → 全 0（透明）
                switch bpp {
                case 32:
                    let s = xorRow * xorRowBytes + x * 4
                    rgba[out] = xor[s + 2]; rgba[out + 1] = xor[s + 1]; rgba[out + 2] = xor[s]; rgba[out + 3] = xor[s + 3]
                case 24:
                    let s = xorRow * xorRowBytes + x * 3
                    rgba[out] = xor[s + 2]; rgba[out + 1] = xor[s + 1]; rgba[out + 2] = xor[s]; rgba[out + 3] = 255
                case 8:
                    let p = palette[Int(xor[xorRow * xorRowBytes + x])]
                    rgba[out] = p.0; rgba[out + 1] = p.1; rgba[out + 2] = p.2; rgba[out + 3] = 255
                default:
                    break
                }
            }
        }
        return CURImage(width: width, height: frameH, rgba: rgba, hotspotX: hx, hotspotY: hy)
    }
}
