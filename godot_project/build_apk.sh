#!/bin/bash
# ============================================================
#  天气小人 v2 · 完整 APK 一键构建脚本
#  产物: 含 Kotlin 原生插件 + Godot 游戏资源, 已签名
#  依赖: Godot 4.4 / Android SDK / Java 17 / Gradle 8.7(自动用缓存)
#  用法: bash build_apk.sh
# ============================================================
set -e

PROJECT="${HOME}/生活自己的代码/weather-pet/godot_project"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
SDK="$HOME/Library/Android/sdk"
TEMPLATE_ZIP="$HOME/Library/Application Support/Godot/export_templates/4.6.3.stable/android_source.zip"
GRADLE8=$(ls ~/.gradle/wrapper/dists/gradle-8.7-bin/*/gradle-8.7/bin/gradle 2>/dev/null | head -1)
KEYSTORE="$HOME/.android/debug.keystore"

# 工具路径
APKSIGNER=$(ls $SDK/build-tools/*/apksigner 2>/dev/null | tail -1)
ZIPALIGN=$(ls $SDK/build-tools/*/zipalign 2>/dev/null | tail -1)

cd "$PROJECT"

echo "================================================"
echo "  步骤 0/5: 生成天气小人应用图标"
echo "================================================"
python3 scripts/make_icon.py 2>&1 | grep -E "✅|🎉"
# 阻止 Godot 扫描 android/res 生成 .import 文件
touch android/res/.gdignore
find android/res/mipmap* -name "*.import" -delete 2>/dev/null
find android/res/mipmap* -name "*.uid" -delete 2>/dev/null
echo "✅ 图标已更新 (icon.png + android mipmap 各分辨率)"

echo ""
echo "================================================"
echo "  步骤 1/5: 标准导出 Godot 游戏资源 (base APK)"
echo "================================================"
# 删除 android/build, 避免 Godot 把 gradle 中间产物当游戏资源打包
rm -rf android/build
cp export_presets.cfg /tmp/exp_presets.bak
sed -i '' 's/gradle_build\/use_gradle_build=true/gradle_build\/use_gradle_build=false/' export_presets.cfg
rm -f base_resource.apk
"$GODOT" --headless --path "$PROJECT" --export-release "Android" "$PROJECT/base_resource.apk" 2>&1 | grep -iE "error|export: end" | head -3
cp /tmp/exp_presets.bak export_presets.cfg
[ -f base_resource.apk ] || { echo "❌ 资源 APK 导出失败"; exit 1; }
echo "✅ 资源 APK: $(du -h base_resource.apk | cut -f1)"

echo ""
echo "================================================"
echo "  步骤 2/5: 安装官方 gradle 模板到 android/build/"
echo "================================================"
rm -rf android/build
mkdir -p android/build
unzip -q -o "$TEMPLATE_ZIP" -d android/build/
echo "✅ 模板解压完成"

echo ""
echo "================================================"
echo "  步骤 3/5: 合并自定义插件 + 配置"
echo "================================================"
# 插件 Kotlin 源码
mkdir -p android/build/src/com/skydiver/weatherpet/plugin
cp android/src/com/skydiver/weatherpet/plugin/WeatherPetPlugin.kt android/build/src/com/skydiver/weatherpet/plugin/
# 项目 manifest (权限 + 插件注册 + 竖屏)
cp android/AndroidManifest.xml android/build/AndroidManifest.xml
# SDK 路径
echo "sdk.dir=$SDK" > android/build/local.properties
# 版本对齐本机缓存 (AGP 8.4.2 + Kotlin 1.9.24 + Gradle 8.7)
sed -i '' "s/androidGradlePlugin: '8.2.0'/androidGradlePlugin: '8.4.2'/" android/build/config.gradle
sed -i '' "s/kotlinVersion      : '1.9.20'/kotlinVersion      : '1.9.24'/" android/build/config.gradle
sed -i '' 's|gradle-8.2-bin.zip|gradle-8.7-bin.zip|' android/build/gradle/wrapper/gradle-wrapper.properties
# 关闭资源优化: 否则 mipmap launcher 图标会被混淆/丢失
sed -i '' 's/android.enableResourceOptimizations=true/android.enableResourceOptimizations=false/' android/build/gradle.properties
# 插件依赖 (androidx.work + play-services-location) - 用 Python 注入避免 sed 多行问题
python3 - "$PROJECT/android/build/build.gradle" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
if 'androidx.work:work-runtime' not in content:
    marker = 'implementation "androidx.core:core-splashscreen:$versions.splashscreenVersion"'
    inject = (marker +
              '\n    implementation "androidx.work:work-runtime:2.9.1"' +
              '\n    implementation "com.google.android.gms:play-services-location:21.3.0"')
    content = content.replace(marker, inject, 1)
    with open(path, 'w') as f:
        f.write(content)
    print("✅ 依赖已注入 build.gradle")
else:
    print("✅ 依赖已存在, 跳过")
PYEOF
# 中文应用名
cat > android/build/res/values/godot_project_name_string.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="godot_project_name_string">天气小人v2</string>
</resources>
EOF
# 复制天气小人 launcher 图标 (各分辨率 mipmap) 到 gradle 工程, 排除 .import 等非资源文件
for dir in mipmap mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi mipmap-anydpi-v26; do
    if [ -d "android/res/$dir" ]; then
        rm -rf "android/build/res/$dir"
        mkdir -p "android/build/res/$dir"
        # 只复制 .png 和 .xml (跳过 Godot 的 .import/.uid/stripped 等文件); 用 nullglob 避免中断
        for f in android/res/$dir/*.png android/res/$dir/*.xml; do
            [ -e "$f" ] && cp "$f" "android/build/res/$dir/"
        done
    fi
done
echo "✅ 插件 + 配置 + 图标合并完成"

echo ""
echo "================================================"
echo "  步骤 4/5: Gradle 编译 (arm 架构, 含 Kotlin 插件)"
echo "================================================"
cd android/build
"$GRADLE8" --no-daemon clean assembleStandardRelease \
  -Pexport_enabled_abis="arm64-v8a|armeabi-v7a" \
  -Pexport_package_name="com.weather.pet" \
  -Pexport_version_code="2" \
  -Pexport_version_name="2.0" 2>&1 | tail -4
cd "$PROJECT"
GRADLE_APK="android/build/build/outputs/apk/standard/release/android_release.apk"
[ -f "$GRADLE_APK" ] || { echo "❌ Gradle 编译失败"; exit 1; }
echo "✅ Gradle APK: $(du -h "$GRADLE_APK" | cut -f1)"

echo ""
echo "================================================"
echo "  步骤 5/5: 注入资源 + 对齐 + 签名"
echo "================================================"
# 提取 Godot 资源
rm -rf /tmp/godot_assets && mkdir -p /tmp/godot_assets
cd /tmp/godot_assets
unzip -oq "$PROJECT/base_resource.apk" "assets/*"
ASSET_COUNT=$(find assets -type f 2>/dev/null | wc -l | tr -d ' ')
cd "$PROJECT"
echo "提取 Godot 资源: $ASSET_COUNT 个文件"

# 合并 + 对齐 + 签名 (用英文名, 避免 Android 工具中文路径问题)
cp "$GRADLE_APK" WeatherPet_tmp.apk
cd /tmp/godot_assets
zip -rq "$PROJECT/WeatherPet_tmp.apk" assets/
cd "$PROJECT"
"$ZIPALIGN" -p -f 4 WeatherPet_tmp.apk WeatherPet_aligned.apk
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey --out WeatherPet_signed.apk WeatherPet_aligned.apk 2>&1 | tail -1
cp WeatherPet_signed.apk "天气小人v2_final.apk"

# 清理中间文件
rm -f WeatherPet_tmp.apk WeatherPet_aligned.apk base_resource.apk

echo ""
echo "================================================"
echo "  🎉 构建完成!"
echo "================================================"
echo "  📦 WeatherPet_signed.apk     $(du -h WeatherPet_signed.apk | cut -f1)"
echo "  📦 天气小人v2_final.apk        $(du -h 天气小人v2_final.apk | cut -f1)  (同上, 中文副本)"
echo ""
echo "  📋 应用信息:"
"$APKSIGNER" verify WeatherPet_signed.apk >/dev/null 2>&1 && echo "     签名: ✅ 有效 (debug key)"
AAPT=$(ls $SDK/build-tools/*/aapt 2>/dev/null | tail -1)
"$AAPT" dump badging WeatherPet_signed.apk 2>/dev/null | grep -E "package:|application-label:" | sed 's/^/     /'
echo "     架构: arm64-v8a, armeabi-v7a"
echo "     插件: WeatherPetPlugin (天气/电量/信号/节日/短信)"
echo ""
echo "  📲 安装方法: adb install WeatherPet_signed.apk"
echo "================================================"