#!/bin/zsh
# 构建 WindowGarden.app（菜单栏引擎）+ 内嵌 WindowGardenWidget.appex（WidgetKit 桌面组件）
# 使用 Xcode 官方构建系统（xcodebuild）：SwiftPM 直接产出的扩展会被系统组件门禁静默拒绝，
# 只有 Xcode 构建的产物（SDK 标记、签名布局与常规 App 一致）才能进入系统组件库。
set -e
cd "$(dirname "$0")/.."

# App Group entitlement 会触发 Xcode 的描述文件检查（本地 ad-hoc 签名无法通过），
# 因此构建时跳过签名，构建完成后用 codesign 手动签（appex 需带 entitlements，先签内层）。
xcodebuild -project WindowGarden.xcodeproj -scheme WindowGarden -configuration Release \
  -derivedDataPath build/xcode CODE_SIGNING_ALLOWED=NO build -quiet

APP="build/xcode/Build/Products/Release/WindowGarden.app"
[ -d "$APP" ] || { echo "构建产物缺失"; exit 1; }

codesign --force --sign - --entitlements WidgetEntitlements.plist \
  "$APP/Contents/PlugIns/WindowGardenWidget.appex"
codesign --force --sign - "$APP"

# 注册到 LaunchServices，让组件出现在系统组件库
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP"

# --install：安装到 /Applications（组件库只收录标准位置的应用）
if [ "$1" = "--install" ]; then
  rm -rf "/Applications/WindowGarden.app"
  cp -R "$APP" "/Applications/WindowGarden.app"
  "$LSREG" -f "/Applications/WindowGarden.app"
  pluginkit -r "$APP/Contents/PlugIns/WindowGardenWidget.appex" 2>/dev/null
  pluginkit -a "/Applications/WindowGarden.app/Contents/PlugIns/WindowGardenWidget.appex" 2>/dev/null
  killall pluginkit 2>/dev/null
  killall NotificationCenter 2>/dev/null
  echo "已安装到 /Applications/WindowGarden.app"
fi

echo "构建完成：$APP"
