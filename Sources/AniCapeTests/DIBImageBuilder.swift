import Foundation

enum DIBImageBuilder {
    /// rgba 行主序、顶行在前；编码为 BITMAPINFOHEADER(biHeight=2h) + XOR(bottom-up, BGRA) + AND mask(bottom-up)
    static func curImage(width: Int, height: Int, rgba: [UInt8]) -> Data {
        var out = Data()
        func add<T: FixedWidthInteger>(_ v: T) { var e = v.littleEndian; withUnsafeBytes(of: &e) { out.append(contentsOf: $0) } }
        add(UInt32(40)); add(Int32(width)); add(Int32(height * 2))
        add(UInt16(1)); add(UInt16(32)); add(UInt32(0))        // planes, bpp, compression = BI_RGB
        add(UInt32(0)); add(Int32(0)); add(Int32(0))           // sizeImage, xppm, yppm
        add(UInt32(0)); add(UInt32(0))                         // clrUsed, clrImportant
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in 0..<width {
                let i = (y * width + x) * 4
                out.append(rgba[i + 2]); out.append(rgba[i + 1]); out.append(rgba[i]); out.append(rgba[i + 3])
            }
        }
        let maskRowBytes = ((width + 31) / 32) * 4
        for y in stride(from: height - 1, through: 0, by: -1) {
            var row = [UInt8](repeating: 0, count: maskRowBytes)
            for x in 0..<width where rgba[(y * width + x) * 4 + 3] == 0 {
                row[x / 8] |= UInt8(0x80 >> (x % 8))
            }
            out.append(contentsOf: row)
        }
        return out
    }
}
