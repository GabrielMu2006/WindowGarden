import AppKit
import GardenCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: GardenController!
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var autoLaunchItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Store.migrateLegacyIfNeeded()
        Store.installBundledArt(from: Bundle.main)
        controller = GardenController()
        installSignalHandlers()
        setupStatusItem()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.saveNow()
    }

    /// SIGTERM/SIGINT 时先落盘再退出（被 kill 也不丢状态）
    private var signalSources: [DispatchSourceSignal] = []
    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                self?.controller?.saveNow()
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }
    }

    // MARK: 菜单栏（R-005：唯一控制面；花园本体是桌面组件，不再有窗口）

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = ImageStore.menubarImage()
            ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Window Garden")

        let refresh = NSMenuItem(title: "刷新组件", action: #selector(refreshWidgets), keyEquivalent: "r")
        refresh.target = self
        let openArt = NSMenuItem(title: "打开插画文件夹", action: #selector(openArtFolder), keyEquivalent: "")
        openArt.target = self
        autoLaunchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleAutoLaunch), keyEquivalent: "")
        autoLaunchItem.target = self
        let about = NSMenuItem(title: "关于 Window Garden", action: #selector(about), keyEquivalent: "")
        about.target = self
        let quit = NSMenuItem(title: "退出 Window Garden", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        menu.addItem(refresh)
        menu.addItem(openArt)
        menu.addItem(autoLaunchItem)
        menu.addItem(.separator())
        menu.addItem(about)
        menu.addItem(.separator())
        menu.addItem(quit)
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    @objc private func refreshWidgets() {
        controller.reloadWidgets()
        wglog("已手动请求组件刷新")
    }

    @objc private func openArtFolder() {
        Store.ensureDirs()
        NSWorkspace.shared.open(Store.artDir)
    }

    @objc private func toggleAutoLaunch() { controller.toggleAutoLaunch() }

    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Window Garden"])
    }

    @objc private func quit() { NSApp.terminate(self) }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        autoLaunchItem.state = AutoLaunch.isEnabled ? .on : .off
    }
}
