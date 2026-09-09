import XCTest
import AppKit

func makeRep(width: Int, height: Int, rgba: [UInt8]) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)
    else { throw NSError(domain: "t", code: 1) }
    rgba.withUnsafeBytes { rep.bitmapData!.update(from: $0.bindMemory(to: UInt8.self).baseAddress!, count: rgba.count) }
    return rep
}

final class LZWProbeTests: XCTestCase {
    func testLZWTIFFRoundTripsWithTopRowFirst() throws {
        let w = 4, h = 2
        let rgba: [UInt8] = [255,0,0,255, 0,255,0,128, 0,0,255,64, 255,255,0,255,
                             255,0,0,255, 0,255,0,128, 0,0,255,64, 255,255,0,255]
        let rep = try makeRep(width: w, height: h, rgba: rgba)
        let tiff = try XCTUnwrap(rep.tiffRepresentation(using: .lzw, factor: 1.0))
        XCTAssertGreaterThan(tiff.count, 0)
        let back = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        XCTAssertEqual(back.pixelsWide, w)
        XCTAssertEqual(back.pixelsHigh, h)
        let data = back.bitmapData!
        var read = [UInt8]()
        read.append(contentsOf: UnsafeBufferPointer(start: data, count: w * h * 4))
        XCTAssertEqual(Array(read), rgba)   // 行0 = 图上排
    }
}
