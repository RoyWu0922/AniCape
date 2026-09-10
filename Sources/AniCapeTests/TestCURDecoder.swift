import Foundation
import AniKit

func testDecodes32bppRoundTrip() throws {
    let w = 4, h = 3
    var rgba = [UInt8](repeating: 255, count: w * h * 4)   // 默认白色不透明
    // (0,0) 红
    rgba[0] = 255; rgba[1] = 0; rgba[2] = 0; rgba[3] = 255
    // (1,2) 半透绿  (row y=2)
    let g = (2 * w + 1) * 4; rgba[g] = 0; rgba[g + 1] = 255; rgba[g + 2] = 0; rgba[g + 3] = 128
    // (2,2) 全透明（AND=1 → 全 0，故源像素须为全 0 才能严格 roundtrip）
    let t = (2 * w + 2) * 4; rgba[t] = 0; rgba[t + 1] = 0; rgba[t + 2] = 0; rgba[t + 3] = 0
    // (3,2) 蓝
    let b = (2 * w + 3) * 4; rgba[b] = 0; rgba[b + 1] = 0; rgba[b + 2] = 255; rgba[b + 3] = 255

    let img = DIBImageBuilder.curImage(width: w, height: h, rgba: rgba)
    let miniCur = ANIBuilder.miniCur(width: UInt8(w), height: UInt8(h), hotspotX: 1, hotspotY: 2, image: img)
    let cur = try CURDecoder.decode(miniCur: miniCur)
    Harness.eq(cur.width, w, "width round-trips")
    Harness.eq(cur.height, h, "height round-trips")
    Harness.eq(cur.hotspotX, 1, "hotspotX round-trips")
    Harness.eq(cur.hotspotY, 2, "hotspotY round-trips")
    Harness.eq(Array(cur.rgba), rgba, "RGBA round-trip (AND=1→全0、AND=0→保 alpha)")
}

func testRejectsCorrupt() {
    Harness.assertThrows({ try CURDecoder.decode(miniCur: Data(repeating: 0, count: 4)) },
                         "decode of 4 zero bytes throws")
}
