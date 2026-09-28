// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowGarden",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GardenCore", targets: ["GardenCore"])
    ],
    targets: [
        // 引擎与组件共享的领域模型、存储、调色板、资产加载与场景渲染
        .target(name: "GardenCore"),
        // 菜单栏引擎（常驻，负责测量活跃时长并驱动组件刷新）
        .executableTarget(
            name: "WindowGarden",
            dependencies: ["GardenCore"],
            path: "Sources/WindowGarden",
            resources: [.copy("Art")]
        ),
        // WidgetKit 组件扩展（桌面小组件）
        .executableTarget(
            name: "WindowGardenWidget",
            dependencies: ["GardenCore"],
            path: "Sources/WindowGardenWidget"
        ),
        // 离屏预览工具：渲染各尺寸×各时段的组件形态图（开发用，不随应用分发）
        .executableTarget(
            name: "GardenPreview",
            dependencies: ["GardenCore"],
            path: "Sources/GardenPreview"
        ),
    ]
)
