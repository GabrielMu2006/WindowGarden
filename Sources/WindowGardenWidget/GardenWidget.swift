import WidgetKit
import SwiftUI
import GardenCore

/// 组件快照：一次时间线内的花园状态
struct GardenSnapshot {
    var plants: [PlantView]
    var away: Bool
    var visitor: VisitorSpecies?
}

struct GardenEntry: TimelineEntry {
    let date: Date
    let snapshot: GardenSnapshot
}

struct GardenProvider: TimelineProvider {
    func placeholder(in context: Context) -> GardenEntry {
        GardenEntry(date: .now, snapshot: snapshot(stageOverride: 2))
    }

    func getSnapshot(in context: Context, completion: @escaping (GardenEntry) -> Void) {
        completion(GardenEntry(date: .now, snapshot: snapshot()))
    }

    /// 时间线策略：未来 24 小时内的每个昼夜相位边界生成一个条目（约 4–6 个），
    /// 生长与访客变化由菜单栏引擎在事件发生时调用 WidgetCenter 主动刷新。
    func getTimeline(in context: Context, completion: @escaping (Timeline<GardenEntry>) -> Void) {
        let snap = snapshot()
        var entries = [GardenEntry(date: .now, snapshot: snap)]
        for boundary in Phase.boundaries(after: .now) {
            entries.append(GardenEntry(date: boundary, snapshot: snap))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func snapshot(stageOverride: Int? = nil) -> GardenSnapshot {
        let state = Store.load()
        let plants = state.plants
            .sorted { $0.slot < $1.slot }
            .map { PlantView(slot: $0.slot, species: Species(rawValue: $0.species) ?? .daisy,
                             stage: stageOverride ?? min(4, max(1, $0.stage))) }
        let visitor = (state.away == true)
            ? (state.visitors ?? []).compactMap { VisitorSpecies(rawValue: $0) }.first
            : nil
        return GardenSnapshot(plants: plants, away: state.away == true, visitor: visitor)
    }
}

struct GardenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WindowGardenWidget", provider: GardenProvider()) { entry in
            GardenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("窗口花园")
        .description("一座随你的使用状态慢慢生长的小花园。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct GardenWidgetEntryView: View {
    var entry: GardenEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                GardenScene(date: entry.date,
                            plants: entry.snapshot.plants,
                            slotFractions: GrowthConfig.slotX,
                            visitor: entry.snapshot.visitor)
            default:
                // 小尺寸：展示前三株植物
                let fractions = [0.28, 0.52, 0.76]
                GardenScene(date: entry.date,
                            plants: Array(entry.snapshot.plants.prefix(fractions.count)),
                            slotFractions: fractions,
                            visitor: entry.snapshot.visitor)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
