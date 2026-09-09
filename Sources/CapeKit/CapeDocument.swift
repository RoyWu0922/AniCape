import Foundation

public enum CapeError: Error {
    case invalidCursor, tiffEncodeFailed, missingRepresentation(String)
}

public struct CapeCursor {
    public let identifier: String
    public let frameDuration: Double
    public let frameWidthPx: Int
    public let frameHeightPx: Int
    public let hotspotX: Int
    public let hotspotY: Int
    public let frames: [[UInt8]]          // 每显示步一条 RGBA，行主序顶行在前
    public init(identifier: String, frameDuration: Double, frameWidthPx: Int, frameHeightPx: Int,
                hotspotX: Int, hotspotY: Int, frames: [[UInt8]]) {
        self.identifier = identifier
        self.frameDuration = frameDuration
        self.frameWidthPx = frameWidthPx
        self.frameHeightPx = frameHeightPx
        self.hotspotX = hotspotX
        self.hotspotY = hotspotY
        self.frames = frames
    }
}

public struct CapeDocument {
    public var name: String
    public var author: String
    public var identifier: String
    public var cursors: [String: CapeCursor]
    public init(name: String, author: String, identifier: String, cursors: [String: CapeCursor]) {
        self.name = name
        self.author = author
        self.identifier = identifier
        self.cursors = cursors
    }
}
