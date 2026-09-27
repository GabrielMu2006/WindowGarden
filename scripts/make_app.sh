#!/bin/zsh
# 构建 WindowGarden.app（菜单栏引擎）+ 内嵌 WindowGardenWidget.appex（WidgetKit 桌面组件）
set -e
cd "$(dirname "$0")/.."

swift build -c release

APP="build/WindowGarden.app"
APPEX="$APP/Contents/PlugIns/WindowGardenWidget.appex"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS"

# 主应用
cp ".build/release/WindowGarden" "$APP/Contents/MacOS/WindowGarden"
cp "Info.plist" "$APP/Contents/Info.plist"
for b in .build/release/*_WindowGarden.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done

# 组件扩展
cp ".build/release/WindowGardenWidget" "$APPEX/Contents/MacOS/WindowGardenWidget"
cp "WidgetInfo.plist" "$APPEX/Contents/Info.plist"

# 签名：先内后外（组件必须沙盒化才会被系统组件框架收录）
codesign --force -s - --entitlements "WidgetEntitlements.plist" "$APPEX"
codesign --force -s - "$APP"

# 注册到 LaunchServices，让组件出现在系统组件库
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP"

# --install：安装到 /Applications（组件库只收录标准位置的应用）
if [ "$1" = "--install" ]; then
  rm -rf "/Applications/WindowGarden.app"
  cp -R "$APP" "/Applications/WindowGarden.app"
  codesign --force -s - --entitlements "WidgetEntitlements.plist" "/Applications/WindowGarden.app/Contents/PlugIns/WindowGardenWidget.appex"
  codesign --force -s - "/Applications/WindowGarden.app"
  "$LSREG" -f "/Applications/WindowGarden.app"
  pluginkit -r "$APP/Contents/PlugIns/WindowGardenWidget.appex" 2>/dev/null
  pluginkit -a "/Applications/WindowGarden.app/Contents/PlugIns/WindowGardenWidget.appex" 2>/dev/null
  echo "已安装到 /Applications/WindowGarden.app"
fi

echo "已生成 $APP（含 WidgetKit 组件扩展）"
