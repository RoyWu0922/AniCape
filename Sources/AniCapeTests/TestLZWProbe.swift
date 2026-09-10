import AppKit

func testLZWProbe() throws {
    let w = 4, h = 2
    // Two DIFFERENT rows so a byte-identical round-trip proves top-row-first ordering.
    let rgba: [UInt8] = [
        255, 0, 0, 255,   0, 255, 0, 128,   0, 0, 255, 64,   255, 255, 0, 255,
        0, 255, 255, 255, 255, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 255
    ]
    let rep = try makeRep(width: w, height: h, rgba: rgba)
    let tiff = try Harness.unwrap(rep.tiffRepresentation(using: .lzw, factor: 1.0), "LZW TIFF produced")
    Harness.check(tiff.count > 0, "LZW TIFF non-empty")
    let back = try Harness.unwrap(NSBitmapImageRep(data: tiff), "TIFF decodes back via NSBitmapImageRep")
    Harness.eq(back.pixelsWide, w, "pixelsWide round-trips")
    Harness.eq(back.pixelsHigh, h, "pixelsHigh round-trips")
    let data = back.bitmapData!
    var read: [UInt8] = []
    read.append(contentsOf: UnsafeBufferPointer(start: data, count: w * h * 4))
    Harness.eq(read, rgba, "byte-identical round-trip (row 0 = top row)")
}

private func makeRep(width: Int, height: Int, rgba: [UInt8]) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)
    else { throw TestError(message: "NSBitmapImageRep init failed") }
    rgba.withUnsafeBytes {
        rep.bitmapData!.update(from: $0.bindMemory(to: UInt8.self).baseAddress!, count: rgba.count)
    }
    return rep
}
