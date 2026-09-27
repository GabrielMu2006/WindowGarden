// Usage:
//   swift scripts/PrepareArt.swift row input.png output-dir plant_daisy 290,660,1095
//   swift scripts/PrepareArt.swift single input.png output.png
// Splits generated four-stage sheets at their actual gutters and removes transparent margins.
import Foundation
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.bitsPerPixel == 32,
          image.bytesPerRow >= image.width * 4,
          image.alphaInfo == .last || image.alphaInfo == .premultipliedLast else {
        fatalError("Expected an RGBA PNG: \(path)")
    }
    return image
}

func trimmed(_ image: CGImage, columns: Range<Int>) -> CGImage {
    guard let data = image.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else { fatalError("Could not read image pixels") }
    var left = columns.upperBound
    var right = columns.lowerBound - 1
    var top = image.height
    var bottom = -1

    for y in 0..<image.height {
        for x in columns {
            let alpha = bytes[y * image.bytesPerRow + x * 4 + 3]
            if alpha >= 8 {
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
            }
        }
    }
    guard right >= left, bottom >= top else { fatalError("No visible pixels in \(columns)") }
    let pad = max(4, Int(Double(max(right - left + 1, bottom - top + 1)) * 0.02))
    let x0 = max(columns.lowerBound, left - pad)
    let x1 = min(columns.upperBound, right + pad + 1)
    let y0 = max(0, top - pad)
    let y1 = min(image.height, bottom + pad + 1)
    let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    guard let crop = image.cropping(to: rect) else { fatalError("Crop failed: \(rect)") }
    return crop
}

func write(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(path)") }
    print("\(path): \(image.width)×\(image.height)")
}

let args = CommandLine.arguments
guard args.count >= 2 else { fatalError("Use row or single") }
switch args[1] {
case "row":
    guard args.count == 6 else { fatalError("row input.png output-dir prefix cut1,cut2,cut3") }
    let image = load(args[2])
    let cuts = args[5].split(separator: ",").compactMap { Int($0) }
    let edges = [0] + cuts + [image.width]
    guard cuts.count == 3, zip(edges, edges.dropFirst()).allSatisfy({ $0 < $1 }) else {
        fatalError("Expected three ascending cut positions inside the image")
    }
    for index in 0..<4 {
        let part = trimmed(image, columns: edges[index]..<edges[index + 1])
        write(part, to: "\(args[3])/\(args[4])_\(index + 1).png")
    }
case "single":
    guard args.count == 4 else { fatalError("single input.png output.png") }
    let image = load(args[2])
    write(trimmed(image, columns: 0..<image.width), to: args[3])
default:
    fatalError("Use row or single")
}
