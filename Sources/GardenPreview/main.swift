import AppKit
import SwiftUI
import GardenCore

// 组件形态预览：用与桌面组件完全相同的渲染代码，离屏产出
// 「小/中尺寸 × 清晨/白天/黄昏/夜晚（+访客）」的总览图，供审视图样。
// 用法: swift run GardenPreview  → 生成 build/preview/widget_previews.png 并打开

let smallSize = CGSize(width: 160, height: 158)
let mediumSize = CGSize(width: 352, height: 158)

func date(atHour h: Int, _ m: Int) -> Date {
    Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
}

/// 示意一个"生长中"的花园：各株处于不同阶段（比实际初始状态更能检验各阶段图样）
let bloomPlants: [PlantView] = [
    PlantView(slot: 0, species: .daisy, stage: 4),
    PlantView(slot: 1, species: .lavender, stage: 3),
    PlantView(slot: 2, species: .tulip, stage: 2),
    PlantView(slot: 3, species: .lilyvalley, stage: 4),
    PlantView(slot: 4, species: .foxglove, stage: 3),
    PlantView(slot: 5, species: .moonflower, stage: 4),
]
let smallFractions = [0.28, 0.52, 0.76]

struct Cell: View {
    let title: String
    let size: CGSize
    let date: Date
    let plants: [PlantView]
    let fractions: [Double]
    let visitor: VisitorSpecies?

    var body: some View {
        VStack(spacing: 7) {
            GardenScene(date: date, plants: plants, slotFractions: fractions, visitor: visitor)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct Sheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Window Garden · 组件形态预览")
                .font(.system(size: 16, weight: .semibold))
            HStack(alignment: .top, spacing: 14) {
                Cell(title: "小 · 清晨", size: smallSize, date: date(atHour: 6, 0),
                     plants: PlantShowcase.smallSelection(from: bloomPlants, night: false),
                     fractions: smallFractions, visitor: nil)
                Cell(title: "小 · 白天", size: smallSize, date: date(atHour: 12, 0),
                     plants: PlantShowcase.smallSelection(from: bloomPlants, night: false),
                     fractions: smallFractions, visitor: nil)
                Cell(title: "小 · 黄昏", size: smallSize, date: date(atHour: 18, 0),
                     plants: PlantShowcase.smallSelection(from: bloomPlants, night: false),
                     fractions: smallFractions, visitor: nil)
                Cell(title: "小 · 夜晚（月见草入镜）", size: smallSize, date: date(atHour: 22, 0),
                     plants: PlantShowcase.smallSelection(from: bloomPlants, night: true),
                     fractions: smallFractions, visitor: nil)
            }
            HStack(alignment: .top, spacing: 14) {
                Cell(title: "中 · 清晨", size: mediumSize, date: date(atHour: 6, 0),
                     plants: bloomPlants, fractions: GrowthConfig.slotX, visitor: nil)
                Cell(title: "中 · 白天", size: mediumSize, date: date(atHour: 12, 0),
                     plants: bloomPlants, fractions: GrowthConfig.slotX, visitor: nil)
                Cell(title: "中 · 黄昏", size: mediumSize, date: date(atHour: 18, 0),
                     plants: bloomPlants, fractions: GrowthConfig.slotX, visitor: nil)
                Cell(title: "中 · 夜晚 + 访客（离开状态）", size: mediumSize, date: date(atHour: 22, 0),
                     plants: bloomPlants, fractions: GrowthConfig.slotX, visitor: .cat)
            }
            Text("注：示意各株处于不同生长阶段（幼苗→盛放）。实际桌面组件由系统按相同代码渲染。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(22)
        .background(Color(white: 0.97))
    }
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)

    let renderer = ImageRenderer(content: Sheet())
    renderer.scale = 2
    renderer.proposedSize = ProposedViewSize(width: 4 * smallSize.width + mediumSize.width + 3 * 14 + 44,
                                            height: 2 * (smallSize.height + 30) + 70)
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("渲染失败\n", stderr)
        exit(1)
    }
    let dir = URL(fileURLWithPath: "build/preview", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let out = dir.appendingPathComponent("widget_previews.png")
    do {
        try png.write(to: out)
        print("已生成 \(out.path)（\(image.size.width)x\(image.size.height)pt）")
        NSWorkspace.shared.open(out)
    } catch {
        fputs("写入失败：\(error)\n", stderr)
        exit(1)
    }
}
