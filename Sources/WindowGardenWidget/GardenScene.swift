import SwiftUI
import GardenCore

/// 花园场景渲染：小/中两种尺寸共用，按组件高度自适应缩放。
/// 组件是系统渲染的静态快照（无逐帧动画），萤火虫/星星位置由日期确定。
struct GardenScene: View {
    let date: Date
    let plants: [PlantView]
    let slotFractions: [Double]
    let visitor: VisitorSpecies?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pal = Palette.of(Phase.current(at: date))
            let groundHeight = h * 0.26
            let baseY = h - groundHeight * 0.42
            let scale = h / 150

            ZStack {
                LinearGradient(colors: [pal.skyTop.color, pal.skyBottom.color],
                               startPoint: .top, endPoint: .bottom)
                celestial(pal, w: w, h: h, scale: scale)
                stars(pal, w: w, h: h, scale: scale)
                clouds(pal, w: w, h: h, scale: scale)
                glowSpots(pal, w: w, baseY: baseY, scale: scale)
                ground(pal, w: w, h: h, groundHeight: groundHeight)
                grassAndStones(pal, w: w, h: h, baseY: baseY, scale: scale)
                plantsLayer(w: w, baseY: baseY, scale: scale)
                visitorLayer(w: w, h: h, baseY: baseY, scale: scale)
                tintOverlays(pal, w: w, h: h)
                fireflies(pal, w: w, h: h, baseY: baseY, scale: scale)
            }
        }
    }

    // MARK: 天体

    @ViewBuilder
    private func celestial(_ pal: Palette, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        if pal.sunOpacity > 0.01 {
            Group {
                if let img = ImageStore.image("ambient.sun") {
                    Image(nsImage: img).resizable().scaledToFit().frame(width: 44 * scale, height: 44 * scale)
                } else {
                    ZStack {
                        Circle().fill(RGB(0xFF, 0xE2, 0xA8).color).blur(radius: 6 * scale).frame(width: 50 * scale, height: 50 * scale)
                        Circle().fill(RGB(0xFF, 0xE9, 0xB8).color).frame(width: 32 * scale, height: 32 * scale)
                    }
                }
            }
            .opacity(pal.sunOpacity)
            .position(x: pal.sunX * w, y: pal.sunY * h)
        }
        if pal.moonOpacity > 0.01 {
            Group {
                if let img = ImageStore.image("ambient.moon") {
                    Image(nsImage: img).resizable().scaledToFit().frame(width: 36 * scale, height: 36 * scale)
                } else {
                    ZStack {
                        Circle().fill(RGB(0xF4, 0xEF, 0xD8).color).blur(radius: 5 * scale).frame(width: 40 * scale, height: 40 * scale)
                        Circle().fill(RGB(0xF4, 0xEF, 0xD8).color).frame(width: 26 * scale, height: 26 * scale)
                    }
                }
            }
            .opacity(pal.moonOpacity)
            .position(x: pal.moonX * w, y: pal.moonY * h)
        }
    }

    // MARK: 星空

    private func stars(_ pal: Palette, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        let img = ImageStore.image("ambient.star")
        let field = Array(DecoField.starField.prefix(14))
        return ForEach(field, id: \.phase) { s in
            let size = CGFloat(s.h) * 5 * scale
            Group {
                if let img {
                    Image(nsImage: img).resizable().scaledToFit().frame(width: size, height: size)
                } else {
                    Circle().fill(Color.white).frame(width: size, height: size)
                }
            }
            .opacity(pal.starOpacity * 0.9)
            .position(x: s.x * w, y: s.y * h)
        }
    }

    // MARK: 云

    private func clouds(_ pal: Palette, w: CGFloat, h: CGFloat, scale: CGFloat) -> some View {
        Group {
            cloud(offset: 0.1, yFrac: 0.22, size: 22 * scale, opacity: 0.85, pal: pal, w: w, h: h)
            cloud(offset: 0.55, yFrac: 0.42, size: 16 * scale, opacity: 0.6, pal: pal, w: w, h: h)
        }
    }

    private func cloud(offset: Double, yFrac: Double, size: CGFloat, opacity: Double, pal: Palette, w: CGFloat, h: CGFloat) -> some View {
        let image = ImageStore.image("ambient.cloud")
        let body: AnyView
        if let image {
            body = AnyView(Image(nsImage: image).resizable().scaledToFit().frame(height: size))
        } else {
            body = AnyView(Capsule().fill(Color.white.opacity(0.85)).frame(width: size * 2.4, height: size * 0.55))
        }
        return body
            .opacity(opacity * (1 - pal.nightStrength))
            .position(x: CGFloat(offset) * w, y: h * yFrac)
    }

    // MARK: 夜间植物柔光（月见草槽位）

    @ViewBuilder
    private func glowSpots(_ pal: Palette, w: CGFloat, baseY: CGFloat, scale: CGFloat) -> some View {
        ForEach(plants) { p in
            if p.species.glowsAtNight, pal.glowOpacity > 0.01, p.slot < slotFractions.count {
                let x = CGFloat(slotFractions[p.slot]) * w
                Circle()
                    .fill(RadialGradient(colors: [
                        RGB(0xFF, 0xED, 0xA8).color.opacity(0.55),
                        RGB(0xFF, 0xED, 0xA8).color.opacity(0),
                    ], center: .center, startRadius: 2, endRadius: 40 * scale))
                    .frame(width: 80 * scale, height: 80 * scale)
                    .opacity(pal.glowOpacity)
                    .position(x: x, y: baseY - 14 * scale)
            }
        }
    }

    // MARK: 地面与点缀

    private func ground(_ pal: Palette, w: CGFloat, h: CGFloat, groundHeight: CGFloat) -> some View {
        Group {
            if let img = ImageStore.image("bg.ground") {
                Image(nsImage: img).resizable().frame(width: w, height: groundHeight)
            } else {
                ZStack(alignment: .top) {
                    Rectangle().fill(pal.soil.color)
                    Rectangle().fill(pal.grassTop.color).frame(height: groundHeight * 0.3)
                }
                .frame(width: w, height: groundHeight)
            }
        }
        .position(x: w / 2, y: h - groundHeight / 2)
    }

    private func grassAndStones(_ pal: Palette, w: CGFloat, h: CGFloat, baseY: CGFloat, scale: CGFloat) -> some View {
        let grassImg = ImageStore.image("ambient.grass")
        let stoneImg = ImageStore.image("ambient.stone")
        let grass = Array(DecoField.grassField.prefix(9))
        let stones = Array(DecoField.stoneField.prefix(3))
        return Group {
            ForEach(grass, id: \.phase) { g in
                let size = CGFloat(g.h) * 11 * scale
                Group {
                    if let grassImg {
                        Image(nsImage: grassImg).resizable().scaledToFit().frame(height: size)
                    } else {
                        Ellipse().fill(pal.grassTop.color).frame(width: size, height: size * 0.5)
                    }
                }
                .position(x: g.x * w, y: baseY - size / 2)
            }
            ForEach(stones, id: \.phase) { s in
                let size = CGFloat(s.h) * 6 * scale
                Group {
                    if let stoneImg {
                        Image(nsImage: stoneImg).resizable().scaledToFit().frame(height: size)
                    } else {
                        Ellipse().fill(RGB(0x8D, 0x8A, 0x80).color).frame(width: size * 1.4, height: size)
                    }
                }
                .position(x: s.x * w, y: baseY + 4 * scale)
            }
        }
    }

    // MARK: 植物

    private func plantsLayer(w: CGFloat, baseY: CGFloat, scale: CGFloat) -> some View {
        ForEach(Array(plants.enumerated()), id: \.element.id) { index, p in
            let species = p.species
            let stageIndex = max(0, min(3, p.stage - 1))
            let rawHeight = GrowthConfig.stageHeights[stageIndex] * CGFloat(species.heightFactor) * scale * 1.15
            let height = min(rawHeight, 80 * scale)
            let fraction = slotFractions[min(index, slotFractions.count - 1)]
            let x = CGFloat(fraction) * w
            let y = baseY - height / 2
            Group {
                if let img = ImageStore.image("plant.\(species.rawValue).\(p.stage)") {
                    Image(nsImage: img).resizable().scaledToFit().frame(height: height)
                } else {
                    Text(species.stageEmoji[stageIndex]).font(.system(size: height * 0.7))
                }
            }
            .position(x: x, y: y)
        }
    }

    // MARK: 访客（离开快照）

    @ViewBuilder
    private func visitorLayer(w: CGFloat, h: CGFloat, baseY: CGFloat, scale: CGFloat) -> some View {
        if let visitor {
            let height = visitor.height * scale * 0.9
            let x = w * 0.9
            Group {
                if let img = ImageStore.image("animal.\(visitor.rawValue)") {
                    Image(nsImage: img).resizable().scaledToFit().frame(height: height)
                } else {
                    Text(visitor.emoji).font(.system(size: height))
                }
            }
            .position(x: x, y: baseY - height / 2)
        }
    }

    // MARK: 氛围叠加

    private func tintOverlays(_ pal: Palette, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(pal.nightColor.color)
                .opacity(pal.nightStrength)
                .blendMode(.multiply)
            Rectangle().fill(pal.warmColor.color)
                .opacity(pal.warmStrength * 0.18)
                .blendMode(.softLight)
        }
    }

    // MARK: 萤火虫

    private func fireflies(_ pal: Palette, w: CGFloat, h: CGFloat, baseY: CGFloat, scale: CGFloat) -> some View {
        let img = ImageStore.image("ambient.firefly")
        let count = 4
        return Group {
            ForEach(0..<count, id: \.self) { i in
                let fi = Double(i)
                let raw = 0.31 * fi + 0.13 * sin(date.timeIntervalSinceReferenceDate * 0.05 + fi * 2.1)
                let fx = w * (0.12 + 0.72 * DecoField.wrap01(raw))
                let fy = baseY - 10 * scale - 18 * scale * (0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate * 0.21 + fi * 1.9))
                Group {
                    if let img {
                        Image(nsImage: img).resizable().scaledToFit().frame(width: 9 * scale, height: 9 * scale)
                    } else {
                        ZStack {
                            Circle().fill(RGB(0xFF, 0xE9, 0xA0).color).opacity(0.5)
                                .frame(width: 8 * scale, height: 8 * scale).blur(radius: 1.5 * scale)
                            Circle().fill(RGB(0xFF, 0xF3, 0xC4).color)
                                .frame(width: 2.5 * scale, height: 2.5 * scale)
                        }
                    }
                }
                .opacity(pal.fireflyOpacity * 0.9)
                .position(x: fx, y: fy)
            }
        }
    }
}
