import SwiftUI
import Foundation
import CoreGraphics
import Core
import CapeKit

/// 把 CapeCursor 的 RGBA 帧转成 CGImage 并缓存。RGBA 是**非预乘**，故用 CGImageAlphaLast。
/// 只做 RGBA → CGImage 的表示层转换，不解析 ANI/CUR/plist。
enum CursorImages {
    private static var cache: [String: [CGImage]] = [:]

    /// 内容指纹：同一 identifier + 同尺寸 + 同帧数的两个不同光标在缓存里必须分开。
    /// 分析阶段的 cursor.identifier 一律是占位符 "local.anicap.pending"，仅靠
    /// identifier / 尺寸 / 帧数无法区分「同为 32×32 单帧」的两个不同文件。
    private static func fingerprint(of cursor: CapeCursor) -> Int {
        var hasher = Hasher()
        for frame in cursor.frames {
            hasher.combine(frame.count)
            frame.withUnsafeBufferPointer { hasher.combine(bytes: UnsafeRawBufferPointer($0)) }
        }
        return hasher.finalize()
    }

    static func images(for cursor: CapeCursor) -> [CGImage] {
        let key = "\(cursor.identifier)|\(cursor.frameWidthPx)x\(cursor.frameHeightPx)|\(cursor.frames.count)|\(fingerprint(of: cursor))"
        if let hit = cache[key] { return hit }
        let space = CGColorSpaceCreateDeviceRGB()
        let built: [CGImage] = cursor.frames.compactMap { rgba in
            guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
            return CGImage(width: cursor.frameWidthPx, height: cursor.frameHeightPx,
                           bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: cursor.frameWidthPx * 4,
                           space: space,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                           provider: provider, decode: nil,
                           shouldInterpolate: false, intent: .defaultIntent)
        }
        cache[key] = built
        return built
    }

    static func firstImage(for cursor: CapeCursor) -> CGImage? { images(for: cursor).first }
}

struct AnimatedCursorView: View {
    let cursor: CapeCursor

    var body: some View {
        let frames = CursorImages.images(for: cursor)
        TimelineView(.animation) { timeline in
            if frames.isEmpty {
                Color.secondary.opacity(0.15)
            } else {
                let period = max(cursor.frameDuration, 1.0 / 60.0)
                let index = Int(timeline.date.timeIntervalSinceReferenceDate / period) % frames.count
                Image(decorative: frames[index], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
