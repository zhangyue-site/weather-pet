#!/bin/bash
# 天气宠物 - 一键自动化脚本
# 用法：双击运行 或在终端 ./setup_mac.command

PROJECT_DIR="${HOME}/Developer/mycode/天气APK小人/godot_project"
GODOT_APP="/Applications/Godot.app"

echo "============================================"
echo "  🌤️ 天气宠物 - Godot 一键自动化设置"
echo "============================================"
echo ""

# 检查 Godot
if [ ! -d "$GODOT_APP" ]; then
    echo "❌ 未找到 Godot，请从 https://godotengine.org/download 下载并安装到 /Applications"
    read -p "按 Enter 退出..."
    exit 1
fi

echo "✅ Godot 引擎已就绪"
echo "📁 项目路径: $PROJECT_DIR"
echo ""

# 步骤1：用 Godot --script 自动创建所有资源
echo "🔨 步骤 1/5: 正在自动创建 Godot 资源..."

"$GODOT_APP/Contents/MacOS/Godot" --headless --path "$PROJECT_DIR" --script "$PROJECT_DIR/scripts/setup_auto.gd"

echo ""
echo "🔨 步骤 2/5: 正在编译 Kotlin 原生插件..."

cd "$PROJECT_DIR/plugin"
DOWNLOAD_GRADLE=false
if [ ! -d "gradle/wrapper" ]; then
    DOWNLOAD_GRADLE=true
    echo "  第一次设置，下载 Gradle（可能需要几分钟）..."
fi

if command -v ./gradlew &> /dev/null || [ -f "gradlew" ]; then
    ./gradlew assembleDebug 2>&1 | tail -20
else
    echo "  使用系统 Gradle..."
    gradle assembleDebug 2>&1 | tail -20
fi

echo ""
echo "🔨 步骤 3/5: 打包 AAR 插件..."

"$PROJECT_DIR/addons/Android/LiveWallpaper/Editor/pack_aar.gd" 2>/dev/null || echo "  通过 Godot 编辑器处理..."

echo ""
echo "🔨 步骤 4/5: 配置 Android 导出..."

"$GODOT_APP/Contents/MacOS/Godot" --headless --path "$PROJECT_DIR" --script "$PROJECT_DIR/scripts/setup_export.gd" 2>&1

echo ""
echo "🔨 步骤 5/5: 导出 Android APK..."

"$GODOT_APP/Contents/MacOS/Godot" --headless --path "$PROJECT_DIR" --export-release "Android" "$PROJECT_DIR/WeatherPet.apk" 2>&1 | tail -30

echo ""
echo "============================================"
if [ -f "$PROJECT_DIR/WeatherPet.apk" ]; then
    echo "  ✅ 成功！APK 已生成: $PROJECT_DIR/WeatherPet.apk"
else
    echo "  ⚠️ 建设中，请检查上方输出"
fi
echo "============================================"
echo ""
echo "📋 后续步骤："
echo "  1. 在 Godot 编辑器中打开 '打开资源' → 项目 → 选择 $PROJECT_DIR"
echo "  2. 检查场景是否自动创建"
echo "  3. 在项目设置中启用 LiveWallpaper 插件"
echo "  4. 配置导出预设 (Android)"
echo "  5. 构建 → 导出 → APK"
echo ""
read -p "按 Enter 退出..."
