import AppKit
import Foundation
import ServiceManagement
import WidgetKit
import GardenCore

// MARK: - 登录项（开机自启动）

enum AutoLaunch {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func enable() throws { try SMAppService.mainApp.register() }
    static func disable() throws { try SMAppService.mainApp.unregister() }
}

/// 花园引擎：活跃累计（R-002）、访客状态（R-004）、持久化（R-006），
/// 并在状态变化时驱动桌面组件刷新（R-009）。
@MainActor
final class GardenController: ObservableObject {
    private(set) var state = PersistedState()

    private var growthMultiplier: Double = 1
    private var debug = false
    private var allowAutoLaunch = true
    private var tickCount = 0
    private var dirty = false
    private var timers: [Timer] = []

    init() {
        let args = ProcessInfo.processInfo.arguments
        debug = args.contains("--debug")
        allowAutoLaunch = !args.contains("--no-autolaunch")
        if let i = args.firstIndex(of: "--growth-x"), args.count > i + 1, let v = Double(args[i + 1]) {
            growthMultiplier = v
        }

        state = Store.load()
        if state.plants.isEmpty {
            state.plants = Species.allCases.enumerated().map { (i, s) in
                PlantRecord(slot: i, species: s.rawValue, stage: 1)
            }
        }
        wglog("启动：activeSeconds=\(String(format: "%.2f", state.activeSeconds / 3600))h stages=\(state.plants.map { String($0.stage) }.joined(separator: ",")) away=\(state.away ?? false)")
    }

    func start() {
        schedule(1) { self.tick() }
        schedule(30) { self.saveIfDirty() }
        schedule(60) { wglog("心跳：idle=\(Int(IdleTime.seconds())) away=\(self.state.away ?? false) active=\(String(format: "%.2f", self.state.activeSeconds / 3600))h") }

        if allowAutoLaunch, Bundle.main.bundleIdentifier != nil, state.autoLaunch, !AutoLaunch.isEnabled {
            do {
                try AutoLaunch.enable()
                wglog("已注册开机自启动")
            } catch {
                wglog("开机自启动注册失败：\(error.localizedDescription)")
            }
        }
        // 启动时把最新状态推给组件
        saveNow()
        reloadWidgets()
    }

    private func schedule(_ interval: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { block() }
        }
        RunLoop.main.add(t, forMode: .common)
        timers.append(t)
    }

    // MARK: 每秒心跳

    private func tick() {
        tickCount += 1
        let idle = IdleTime.seconds()
        if debug && tickCount % 5 == 0 {
            wglog("tick idle=\(Int(idle)) away=\(state.away ?? false) active=\(String(format: "%.2f", state.activeSeconds / 3600))h")
        }

        // 专注生长：只随"正在使用"累计，与墙钟无关（时钟跳变免疫）
        if idle < GrowthConfig.idleActiveLimit {
            state.activeSeconds += growthMultiplier
            dirty = true
            advanceGrowthIfNeeded()
        }

        // 离开与回归（组件在下次刷新时显示访客快照）
        if state.away != true && idle >= GrowthConfig.awayThreshold {
            enterAway()
        } else if state.away == true && idle < GrowthConfig.idleActiveLimit {
            exitAway()
        }
    }

    // MARK: 专注生长（R-002）

    private func totalAdvancements() -> Int {
        state.plants.reduce(0) { $0 + ($1.stage - 1) }
    }

    private func advanceGrowthIfNeeded() {
        var advanced = false
        while state.activeSeconds >= Double(totalAdvancements() + 1) * GrowthConfig.stageSeconds {
            guard let idx = youngestIndex() else { break }
            state.plants[idx].stage = min(4, state.plants[idx].stage + 1)
            if let s = Species(rawValue: state.plants[idx].species) {
                wglog("生长：\(s.displayName)（槽位\(state.plants[idx].slot)）→ 阶段\(state.plants[idx].stage)")
            }
            advanced = true
        }
        if advanced {
            dirty = true
            saveNow()
            reloadWidgets()
        }
    }

    /// 推进顺序：当前最幼的植物优先；同阶段取槽位靠前
    private func youngestIndex() -> Array<PlantRecord>.Index? {
        guard !state.plants.isEmpty else { return nil }
        return state.plants.indices.min { a, b in
            let sa = state.plants[a].stage, sb = state.plants[b].stage
            return sa == sb ? state.plants[a].slot < state.plants[b].slot : sa < sb
        }
    }

    // MARK: 离开来访（R-004；组件侧呈现）

    private func enterAway() {
        state.away = true
        let count = Int.random(in: 1...3)
        state.visitors = VisitorSpecies.allCases.shuffled().prefix(count).map { $0.rawValue }
        wglog("进入离开状态，访客：\((state.visitors ?? []).map { VisitorSpecies(rawValue: $0)?.displayName ?? $0 }.joined(separator: "、"))")
        saveNow()
        reloadWidgets()
    }

    private func exitAway() {
        state.away = false
        state.visitors = []
        wglog("用户回来了，访客散去")
        saveNow()
        reloadWidgets()
    }

    // MARK: 自启动（R-005）

    func toggleAutoLaunch() {
        state.autoLaunch.toggle()
        if Bundle.main.bundleIdentifier == nil {
            wglog("裸二进制运行，无法变更登录项")
            return
        }
        do {
            if state.autoLaunch { try AutoLaunch.enable() } else { try AutoLaunch.disable() }
        } catch {
            wglog("登录项变更失败：\(error.localizedDescription)")
        }
        dirty = true
        saveNow()
    }

    // MARK: 组件刷新与持久化（R-006 / R-009）

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveIfDirty() {
        guard dirty else { return }
        saveNow()
    }

    func saveNow() {
        Store.save(state)
        dirty = false
    }
}
