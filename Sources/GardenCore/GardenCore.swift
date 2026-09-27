import AppKit
import CoreGraphics
import Foundation

public func wglog(_ message: String) {
    FileHandle.standardError.write(Data("[WindowGarden] \(message)\n".utf8))
}

// MARK: - 配置（对应 SPEC 中的"提议值"，集中调参）

public enum GrowthConfig {
    /// 每推进一个生长阶段所需的累计活跃小时数
    public static let stageHours: Double = 8
    public static var stageSeconds: Double { stageHours * 3600 }
    /// 空闲低于该秒数视为"正在使用电脑"
    public static let idleActiveLimit: Double = 30
    /// 空闲超过该秒数进入"离开"状态，小动物到访
    public static let awayThreshold: Double = 300
    /// 生长阶段显示高度（pt），索引 = 阶段-1
    public static let stageHeights: [CGFloat] = [22, 40, 58, 78]
    /// 六个种植位的水平位置（占宽度比例）
    public static let slotX: [Double] = [0.07, 0.21, 0.36, 0.52, 0.68, 0.85]
    public static let slotYOffset: [CGFloat] = [-3, 2, -1, 3, -2, 1]
}

// MARK: - 植物与访客物种

public enum Species: String, CaseIterable, Codable {
    case daisy, lavender, tulip, lilyvalley, foxglove, moonflower

    public var displayName: String {
        switch self {
        case .daisy: return "雏菊"
        case .lavender: return "薰衣草"
        case .tulip: return "郁金香"
        case .lilyvalley: return "铃兰"
        case .foxglove: return "毛地黄"
        case .moonflower: return "月见草"
        }
    }

    public var heightFactor: Double {
        switch self {
        case .daisy: return 0.85
        case .lavender: return 1.0
        case .tulip: return 0.9
        case .lilyvalley: return 0.8
        case .foxglove: return 1.15
        case .moonflower: return 0.95
        }
    }

    public var glowsAtNight: Bool { self == .moonflower }

    /// 占位资产：各阶段 emoji
    public var stageEmoji: [String] {
        switch self {
        case .daisy: return ["🌱", "🌿", "🌾", "🌼"]
        case .lavender: return ["🌱", "🌿", "🌾", "🪻"]
        case .tulip: return ["🌱", "🌿", "🌾", "🌷"]
        case .lilyvalley: return ["🌱", "🌿", "🌾", "🌸"]
        case .foxglove: return ["🌱", "🌿", "🌾", "💮"]
        case .moonflower: return ["🌱", "🌿", "🌾", "🌼"]
        }
    }
}

public enum VisitorSpecies: String, CaseIterable, Codable {
    case cat, bird, hedgehog

    public var displayName: String {
        switch self {
        case .cat: return "小猫"
        case .bird: return "小鸟"
        case .hedgehog: return "刺猬"
        }
    }

    public var height: CGFloat {
        switch self {
        case .cat: return 26
        case .bird: return 16
        case .hedgehog: return 18
        }
    }

    public var emoji: String {
        switch self {
        case .cat: return "🐈"
        case .bird: return "🐦"
        case .hedgehog: return "🦔"
        }
    }
}

// MARK: - 渲染侧数据结构

public struct PlantView: Identifiable {
    public let slot: Int
    public let species: Species
    public var stage: Int
    public var id: Int { slot }

    public init(slot: Int, species: Species, stage: Int) {
        self.slot = slot
        self.species = species
        self.stage = stage
    }
}

// MARK: - 持久化状态

public struct PlantRecord: Codable {
    public var slot: Int
    public var species: String
    public var stage: Int

    public init(slot: Int, species: String, stage: Int) {
        self.slot = slot
        self.species = species
        self.stage = stage
    }
}

public struct PersistedState: Codable {
    public var version = 1
    /// 全局累计活跃秒数（生长引擎的时间源，与墙钟无关）
    public var activeSeconds: Double = 0
    public var plants: [PlantRecord] = []
    public var hidden = false
    public var autoLaunch = true
    /// 当前是否处于"离开"状态（组件据此显示访客快照）
    public var away: Bool?
    /// 离开期间在场的访客（物种 rawValue）
    public var visitors: [String]?

    public init() {}
}

// MARK: - 存储与应用支持目录

public enum Store {
    public static var rootDir: URL {
        if let p = ProcessInfo.processInfo.environment["WG_STATE_DIR"], !p.isEmpty {
            return URL(fileURLWithPath: p, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WindowGarden", isDirectory: true)
    }

    public static var stateURL: URL { rootDir.appendingPathComponent("state.json") }
    public static var artDir: URL { rootDir.appendingPathComponent("art", isDirectory: true) }

    /// 仅由菜单栏引擎调用；组件只读
    public static func ensureDirs() {
        try? FileManager.default.createDirectory(at: artDir, withIntermediateDirectories: true)
        let readme = artDir.appendingPathComponent("README.txt")
        if !FileManager.default.fileExists(atPath: readme.path) {
            let text = """
            应用首次启动时会把内置插画复制到这里。可按 manifest.json 的文件名替换 PNG 自定义花园。
            完整的生成提示词与命名对照见项目仓库的 ART_PROMPTS.md。替换后可从菜单栏刷新组件。
            """
            try? text.write(to: readme, atomically: true, encoding: .utf8)
        }
    }

    /// 首次启动时安装随应用打包的插画；已有文件视为用户自定义资源，不覆盖。
    public static func installBundledArt(from bundle: Bundle) {
        ensureDirs()
        guard let sourceDir = bundle.resourceURL?.appendingPathComponent("Art", isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil) else {
            wglog("未找到内置插画目录")
            return
        }
        for source in files where source.pathExtension == "png" || source.lastPathComponent == "manifest.json" {
            let destination = artDir.appendingPathComponent(source.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                wglog("安装插画失败：\(source.lastPathComponent)：\(error.localizedDescription)")
            }
        }
    }

    public static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: stateURL) else { return PersistedState() }
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            wglog("状态文件损坏，视为全新花园：\(error.localizedDescription)")
            return PersistedState()
        }
    }

    public static func save(_ s: PersistedState) {
        ensureDirs()
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(s).write(to: stateURL, options: .atomic)
        } catch {
            wglog("保存失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 全局空闲时间（免权限查询）

public enum IdleTime {
    public static func seconds() -> Double {
        if let anyType = CGEventType(rawValue: UInt32.max) {
            return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyType)
        }
        let watched: [CGEventType] = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .mouseMoved, .keyDown, .scrollWheel]
        return watched.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? 0
    }
}

// MARK: - 资产清单与图片加载（R-007：工程与美术解耦）

/// 清单从 art 目录读取（引擎启动时会把内置清单拷贝过去），缺失时退回内置命名约定。
/// 线程安全：组件扩展的 TimelineProvider 可能不在主线程调用。
public enum ImageStore {
    private static let cache = NSCache<NSString, NSImage>()
    private static var manifestMap: [String: String]? = {
        let url = Store.artDir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        return Dictionary(uniqueKeysWithValues: m.elements.map { ($0.key, $0.file) })
    }()

    struct Manifest: Decodable {
        let version: Int
        let elements: [Element]
        struct Element: Decodable {
            let key: String
            let file: String
            let zh: String?
        }
    }

    public static func fallbackMap() -> [String: String] {
        var m: [String: String] = [:]
        for s in Species.allCases {
            for stage in 1...4 { m["plant.\(s.rawValue).\(stage)"] = "plant_\(s.rawValue)_\(stage).png" }
        }
        for v in VisitorSpecies.allCases { m["animal.\(v.rawValue)"] = "animal_\(v.rawValue).png" }
        m["ambient.sun"] = "ambient_sun.png"
        m["ambient.moon"] = "ambient_moon.png"
        m["ambient.cloud"] = "ambient_cloud.png"
        m["ambient.star"] = "ambient_star.png"
        m["ambient.firefly"] = "ambient_firefly.png"
        m["ambient.grass"] = "ambient_grass.png"
        m["ambient.stone"] = "ambient_stone.png"
        m["bg.ground"] = "bg_ground.png"
        m["menubar"] = "menubar_leaf.png"
        return m
    }

    /// 按清单 key 加载图片；文件缺失返回 nil（视图层画占位）
    public static func image(_ key: String) -> NSImage? {
        let map = manifestMap ?? fallbackMap()
        guard let file = map[key] else { return nil }
        let url = Store.artDir.appendingPathComponent(file)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = attributes[.size] as? NSNumber
        let cacheKey = "\(key)|\(modified)|\(size?.intValue ?? 0)" as NSString
        if let hit = cache.object(forKey: cacheKey) { return hit }
        guard let img = NSImage(contentsOf: url) else { return nil }
        cache.setObject(img, forKey: cacheKey)
        return img
    }

    public static func menubarImage() -> NSImage? {
        guard let img = image("menubar") else { return nil }
        let template = img.copy() as! NSImage
        template.isTemplate = true
        return template
    }
}

// MARK: - 装饰布点（种子随机，两端一致）

public struct Deco: Hashable {
    public let x: Double
    public let y: Double
    public let h: Double
    public let phase: Double

    public init(x: Double, y: Double, h: Double, phase: Double) {
        self.x = x; self.y = y; self.h = h; self.phase = phase
    }
}

func seededRandom(_ seed: inout UInt64) -> Double {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Double((seed >> 33) & 0xFFFFFFFF) / Double(0xFFFFFFFF)
}

func decoField(_ count: Int, seed: UInt64, yRange: ClosedRange<Double>, hRange: ClosedRange<Double>) -> [Deco] {
    var s = seed
    return (0..<count).map { _ in
        Deco(x: 0.02 + 0.96 * seededRandom(&s),
             y: yRange.lowerBound + (yRange.upperBound - yRange.lowerBound) * seededRandom(&s),
             h: hRange.lowerBound + (hRange.upperBound - hRange.lowerBound) * seededRandom(&s),
             phase: seededRandom(&s) * 6.28)
    }
}

public enum DecoField {
    public static let starField = decoField(22, seed: 7, yRange: 0.05...0.5, hRange: 0.8...1.8)
    public static let grassField = decoField(16, seed: 99, yRange: 0...0, hRange: 0.7...1.3)
    public static let stoneField = decoField(5, seed: 41, yRange: 0...0, hRange: 0.7...1.4)

    public static func wrap01(_ v: Double) -> Double {
        let r = v.truncatingRemainder(dividingBy: 1)
        return r < 0 ? r + 1 : r
    }
}
