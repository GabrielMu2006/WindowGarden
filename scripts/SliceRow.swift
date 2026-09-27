// 用法: swift scripts/SliceRow.swift <某行植物图.png> <输出前缀>
// 把一张"四阶段横排"生成图切成 4 张等宽图：前缀_1.png ... 前缀_4.png（从左到右 = 阶段1..4）
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    print("用法: swift scripts/SliceRow.swift <输入图.png> <输出前缀>")
    exit(1)
}
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("无法读取输入图像：\(args[1])")
    exit(1)
}

let w = img.width
let h = img.height
let quarter = w / 4
print("输入 \(w)x\(h)，切成 4 张 \(quarter)x\(h)")

for i in 0..<4 {
    let rect = CGRect(x: i * quarter, y: 0, width: quarter, height: h)
    guard let crop = img.cropping(to: rect) else {
        print("裁剪失败（阶段 \(i + 1)）")
        exit(1)
    }
    let out = URL(fileURLWithPath: "\(args[2])_\(i + 1).png")
    guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("无法写入 \(out.path)")
        exit(1)
    }
    CGImageDestinationAddImage(dest, crop, nil)
    guard CGImageDestinationFinalize(dest) else {
        print("写入失败 \(out.path)")
        exit(1)
    }
    print("已写 \(out.path)")
}
