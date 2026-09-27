import SwiftUI

/// 线性插值的 RGB 颜色
public struct RGB {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = Double(r) / 255
        self.g = Double(g) / 255
        self.b = Double(b) / 255
    }

    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    public var color: Color { Color(red: r, green: g, blue: b) }

    public static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
    }
}

/// 昼夜四相位（R-003）：清晨 05:30–08:00 / 白天 08:00–17:30 / 黄昏 17:30–19:30 / 夜晚 19:30–05:30
public enum Phase: Equatable {
    case dawn, day, dusk, night

    public static func current(at date: Date = Date(), offsetMinutes: Int = 0) -> Phase {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        var m = (comps.hour ?? 0) * 60 + (comps.minute ?? 0) + offsetMinutes
        m = ((m % 1440) + 1440) % 1440
        switch m {
        case 330..<480: return .dawn
        case 480..<1050: return .day
        case 1050..<1170: return .dusk
        default: return .night
        }
    }

    /// 相位边界时刻（分钟）：清晨/白天/黄昏/夜晚的起点
    public static let boundaryMinutes = [330, 480, 1050, 1170]

    /// 从 date 起未来 24 小时内的相位边界时刻，供组件生成时间线条目
    public static func boundaries(after date: Date, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset,
                                          to: calendar.startOfDay(for: date)) else { continue }
            for m in Self.boundaryMinutes {
                if let d = calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day), d > date {
                    result.append(d)
                }
            }
        }
        return Array(result.sorted().prefix(6))
    }
}

/// 一个相位下的全套视觉参数（可插值）
public struct Palette {
    public var skyTop: RGB
    public var skyBottom: RGB
    public var grassTop: RGB
    public var soil: RGB
    public var sunOpacity: Double
    public var sunX: Double
    public var sunY: Double
    public var moonOpacity: Double
    public var moonX: Double
    public var moonY: Double
    public var starOpacity: Double
    public var fireflyOpacity: Double
    public var glowOpacity: Double
    public var nightColor: RGB
    public var nightStrength: Double
    public var warmColor: RGB
    public var warmStrength: Double

    public static func of(_ p: Phase) -> Palette {
        switch p {
        case .night:
            return Palette(
                skyTop: RGB(0x0A, 0x10, 0x24), skyBottom: RGB(0x25, 0x31, 0x58),
                grassTop: RGB(0x2F, 0x4A, 0x3C), soil: RGB(0x28, 0x25, 0x21),
                sunOpacity: 0, sunX: 0.7, sunY: 0.3,
                moonOpacity: 0.95, moonX: 0.26, moonY: 0.24,
                starOpacity: 0.9, fireflyOpacity: 0.95, glowOpacity: 0.85,
                nightColor: RGB(0x50, 0x63, 0x92), nightStrength: 0.52,
                warmColor: RGB(0xFF, 0xC8, 0x9A), warmStrength: 0
            )
        case .dawn:
            return Palette(
                skyTop: RGB(0x5C, 0x6E, 0xA6), skyBottom: RGB(0xF2, 0xC4, 0x9C),
                grassTop: RGB(0x7A, 0x9A, 0x55), soil: RGB(0x5A, 0x4A, 0x38),
                sunOpacity: 0.9, sunX: 0.18, sunY: 0.72,
                moonOpacity: 0, moonX: 0.8, moonY: 0.2,
                starOpacity: 0.15, fireflyOpacity: 0.12, glowOpacity: 0.1,
                nightColor: RGB(0x50, 0x63, 0x92), nightStrength: 0.16,
                warmColor: RGB(0xFF, 0xC8, 0x9A), warmStrength: 0.4
            )
        case .day:
            return Palette(
                skyTop: RGB(0x7A, 0xB4, 0xE6), skyBottom: RGB(0xD8, 0xEF, 0xFB),
                grassTop: RGB(0x8C, 0xBB, 0x66), soil: RGB(0x6B, 0x54, 0x3E),
                sunOpacity: 1, sunX: 0.74, sunY: 0.2,
                moonOpacity: 0, moonX: 0.8, moonY: 0.2,
                starOpacity: 0, fireflyOpacity: 0, glowOpacity: 0,
                nightColor: RGB(0x50, 0x63, 0x92), nightStrength: 0,
                warmColor: RGB(0xFF, 0xC8, 0x9A), warmStrength: 0
            )
        case .dusk:
            return Palette(
                skyTop: RGB(0x3E, 0x44, 0x70), skyBottom: RGB(0xE8, 0x96, 0x78),
                grassTop: RGB(0x6E, 0x8A, 0x4E), soil: RGB(0x50, 0x42, 0x33),
                sunOpacity: 0.85, sunX: 0.88, sunY: 0.68,
                moonOpacity: 0.12, moonX: 0.2, moonY: 0.22,
                starOpacity: 0.35, fireflyOpacity: 0.35, glowOpacity: 0.3,
                nightColor: RGB(0x50, 0x63, 0x92), nightStrength: 0.26,
                warmColor: RGB(0xFF, 0x9E, 0x7A), warmStrength: 0.5
            )
        }
    }

    public static func lerp(_ a: Palette, _ b: Palette, _ t: Double) -> Palette {
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return Palette(
            skyTop: RGB.lerp(a.skyTop, b.skyTop, t),
            skyBottom: RGB.lerp(a.skyBottom, b.skyBottom, t),
            grassTop: RGB.lerp(a.grassTop, b.grassTop, t),
            soil: RGB.lerp(a.soil, b.soil, t),
            sunOpacity: mix(a.sunOpacity, b.sunOpacity),
            sunX: mix(a.sunX, b.sunX),
            sunY: mix(a.sunY, b.sunY),
            moonOpacity: mix(a.moonOpacity, b.moonOpacity),
            moonX: mix(a.moonX, b.moonX),
            moonY: mix(a.moonY, b.moonY),
            starOpacity: mix(a.starOpacity, b.starOpacity),
            fireflyOpacity: mix(a.fireflyOpacity, b.fireflyOpacity),
            glowOpacity: mix(a.glowOpacity, b.glowOpacity),
            nightColor: RGB.lerp(a.nightColor, b.nightColor, t),
            nightStrength: mix(a.nightStrength, b.nightStrength),
            warmColor: RGB.lerp(a.warmColor, b.warmColor, t),
            warmStrength: mix(a.warmStrength, b.warmStrength)
        )
    }
}
