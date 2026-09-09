import Foundation

public enum CapeEnvelope {
    public static func plistData(cape: CapeDocument, tiff: [String: Data]) throws -> Data {
        var cursors: [String: [String: Any]] = [:]
        for (id, cur) in cape.cursors {
            guard let t = tiff[id] else { throw CapeError.missingRepresentation(id) }
            cursors[id] = [
                "FrameCount": cur.frames.count,
                "FrameDuration": cur.frameDuration as Double,
                "HotSpotX": Double(cur.hotspotX),
                "HotSpotY": Double(cur.hotspotY),
                "PointsWide": Double(cur.frameWidthPx),
                "PointsHigh": Double(cur.frameHeightPx),
                "Representations": [t],
            ]
        }
        let root: [String: Any] = [
            "MinimumVersion": 2.0 as Double,
            "Version": 2.0 as Double,
            "CapeName": cape.name,
            "CapeVersion": 1.0 as Double,
            "Cloud": false,
            "Author": cape.author,
            "HiDPI": false,
            "Identifier": cape.identifier,
            "Cursors": cursors,
        ]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }
}
