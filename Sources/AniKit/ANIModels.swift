import Foundation

public enum ANIError: Error, Equatable {
    case notRIFF, notACON, truncated, noFrames, invalidFrameCount
}

public struct ANIHeader {
    public let declaredFrames: Int
    public let defaultRateJiffies: Int
    public let width: Int
    public let height: Int
    public init(declaredFrames: Int, defaultRateJiffies: Int, width: Int, height: Int) {
        self.declaredFrames = declaredFrames
        self.defaultRateJiffies = defaultRateJiffies
        self.width = width
        self.height = height
    }
}

public struct ParsedANI {
    public var header: ANIHeader
    public var frameBodies: [Data]
    public var rates: [Int]?
    public var seq: [Int]?
    public init(header: ANIHeader, frameBodies: [Data], rates: [Int]?, seq: [Int]?) {
        self.header = header
        self.frameBodies = frameBodies
        self.rates = rates
        self.seq = seq
    }
}

public enum ANIDocumentError: Error, Equatable {
    case mismatchedFrameSize(Int), badSeq, tooManyFrames(Int)
}

public struct ANIDocument {
    public let frames: [CURImage]
    public let displayIndices: [Int]
    public let frameDuration: Double
    public var displayCount: Int { displayIndices.count }
    public init(frames: [CURImage], displayIndices: [Int], frameDuration: Double) {
        self.frames = frames; self.displayIndices = displayIndices; self.frameDuration = frameDuration
    }
}
