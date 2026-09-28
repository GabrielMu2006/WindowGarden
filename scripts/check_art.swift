// 用法: swift scripts/check_art.swift  — 批量质检 art 目录的插画
// 输出：尺寸、透明像素占比、内容包络盒（左右/底部间隙，0=贴边）、疑似白底占比
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let fm = FileManager.default
let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/WindowGarden/art")
let files = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []

func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }

print(pad("文件", 26) + pad("尺寸", 12) + pad("透明%", 7) + pad("底隙%", 7) + pad("左隙%", 7) + pad("右隙%", 7) + pad("白底%", 7) + pad("边α中位", 8))

for url in files {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        print(pad(url.lastPathComponent, 26) + " 读取失败")
        continue
    }
    let w = img.width, h = img.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let data = ctx.data else { continue }
    let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

    var transparent = 0, opaque = 0
    var minX = w, maxX = -1, minY = h, maxY = -1
    var nearWhiteOpaque = 0
    var borderAlphas: [UInt8] = []
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let a = px[i + 3]
            if x == 0 || y == 0 || x == w - 1 || y == h - 1 { borderAlphas.append(a) }
            if a < 10 {
                transparent += 1
            } else {
                opaque += 1
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                if a > 200 && r > 242 && g > 242 && b > 242 { nearWhiteOpaque += 1 }
            }
        }
    }
    // 边框像素透明度中位数：0=干净的透明底；>0 且 <255=整图带半透明底色（问题）
    borderAlphas.sort()
    let borderMedian = borderAlphas.isEmpty ? 0 : Int(borderAlphas[borderAlphas.count / 2])
    let total = w * h
    let transPct = Double(transparent) / Double(total) * 100
    // CG 坐标 y=0 在底部；包络盒需翻转成“视觉底部”
    _ = h - 1 - minY
    let visMinY = h - 1 - maxY      // 视觉最低一行
    let bottomGap = Double(visMinY) / Double(h) * 100          // 0 = 内容贴画布底边
    let leftGap = Double(minX) / Double(w) * 100
    let rightGap = Double(w - 1 - maxX) / Double(w) * 100
    let whitePct = opaque > 0 ? Double(nearWhiteOpaque) / Double(opaque) * 100 : 0
    print(pad(url.lastPathComponent, 26)
          + pad("\(w)x\(h)", 12)
          + pad(String(format: "%.0f", transPct), 7)
          + pad(String(format: "%.1f", bottomGap), 7)
          + pad(String(format: "%.1f", leftGap), 7)
          + pad(String(format: "%.1f", rightGap), 7)
          + pad(String(format: "%.0f", whitePct), 7) + pad(String(borderMedian), 8))
}
