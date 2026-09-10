import Foundation

enum ANIBuilder {
    static func riffChunk(_ id: String, _ body: Data) -> Data {
        var out = Data()
        out.append(id.data(using: .ascii)!)
        var len = UInt32(body.count).littleEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(body)
        if body.count % 2 == 1 { out.append(0) }
        return out
    }
    static func listChunk(_ type: String, _ children: [Data]) -> Data {
        var body = type.data(using: .ascii)!
        for c in children { body.append(c) }
        return riffChunk("LIST", body)
    }
    static func miniCur(width: UInt8, height: UInt8, hotspotX: UInt16, hotspotY: UInt16, image: Data) -> Data {
        var out = Data()
        out.append(Data([0, 0, 2, 0, 1, 0]))            // ICONDIR: reserved, type=2 (cur), count=1
        out.append(width); out.append(height)
        out.append(0); out.append(0)                    // colors, reserved
        var hx = hotspotX.littleEndian; withUnsafeBytes(of: &hx) { out.append(contentsOf: $0) }
        var hy = hotspotY.littleEndian; withUnsafeBytes(of: &hy) { out.append(contentsOf: $0) }
        var n = UInt32(image.count).littleEndian; withUnsafeBytes(of: &n) { out.append(contentsOf: $0) }
        var o = UInt32(22).littleEndian; withUnsafeBytes(of: &o) { out.append(contentsOf: $0) }
        out.append(image)
        return out
    }
    static func anih(frames: UInt32, jiffies: UInt32) -> Data {
        var b = Data()
        func add<T: FixedWidthInteger>(_ v: T) { var e = v.littleEndian; withUnsafeBytes(of: &e) { b.append(contentsOf: $0) } }
        add(UInt32(36)); add(frames); add(frames); add(UInt32(0)); add(UInt32(0))
        add(UInt32(0)); add(UInt32(0)); add(jiffies); add(UInt32(1))
        return b
    }
    static func build(frames: [[(w: UInt8, h: UInt8, hsx: UInt16, hsy: UInt16, image: Data)]],
                       declaredFrames: UInt32, jiffies: UInt32,
                       rates: [UInt32]? = nil, seq: [UInt32]? = nil) -> Data {
        var body = riffChunk("anih", anih(frames: declaredFrames, jiffies: jiffies))
        if let rates {
            var r = Data()
            for v in rates { var e = v.littleEndian; withUnsafeBytes(of: &e) { r.append(contentsOf: $0) } }
            body.append(riffChunk("rate", r))
        }
        if let seq {
            var s = Data()
            for v in seq { var e = v.littleEndian; withUnsafeBytes(of: &e) { s.append(contentsOf: $0) } }
            body.append(riffChunk("seq ", s))
        }
        // Each frame is a cursor body wrapped as an "icon" chunk inside the "fram" LIST
        // (this is what the ANI spec and ANIReader's LIST parser expect).
        let icons = frames.map { f in
            riffChunk("icon", miniCur(width: f[0].w, height: f[0].h, hotspotX: f[0].hsx,
                                      hotspotY: f[0].hsy, image: f[0].image))
        }
        body.append(listChunk("fram", icons))
        var file = Data("RIFF".utf8)
        var len = UInt32(body.count + 4).littleEndian; withUnsafeBytes(of: &len) { file.append(contentsOf: $0) }
        file.append(Data("ACON".utf8)); file.append(body)
        return file
    }
}
