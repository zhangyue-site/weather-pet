#!/usr/bin/env python3
"""Build the companion APK from the official local Godot source template.

Uses a separate ignored build directory and a separate application id.
The debug signing identity is for local installation, not a store release.
"""
from pathlib import Path
import os
import shutil
import subprocess
import zipfile
import tempfile

PROJECT = Path(__file__).resolve().parent
OUTPUT = PROJECT.parent / "builds"
BUILD = PROJECT / ".companion_build"
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
SDK = Path.home() / "Library/Android/sdk"
JAVA = Path.home() / "Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"
VERSION_CODE = int(os.environ.get("WEATHER_VERSION_CODE", "103"))
VERSION_NAME = os.environ.get("WEATHER_VERSION_NAME", "1.2.1")
TEMPLATE = Path.home() / "Library/Application Support/Godot/export_templates/4.4.1.stable/android_source.zip"

def run(args, cwd=PROJECT):
    subprocess.run([str(x) for x in args], cwd=cwd, env={**os.environ, "JAVA_HOME":str(JAVA)}, check=True)

def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(exist_ok=True)
    (BUILD / ".gdignore").touch()
    gradles = list((Path.home()/".gradle/wrapper/dists").glob("gradle-8.9-bin/*/gradle-8.9/bin/gradle"))
    if not gradles:
        gradles = list((Path.home()/".gradle/wrapper/dists").glob("gradle-8.14-bin/*/gradle-8.14/bin/gradle"))
    if not gradles:
        raise RuntimeError("Cached Gradle 8.9 or 8.14 required")
    if not (BUILD / "build.gradle").exists():
        with zipfile.ZipFile(TEMPLATE) as archive:
            archive.extractall(BUILD)
    config = BUILD / "config.gradle"
    text = config.read_text().replace("androidGradlePlugin: '8.2.0'", "androidGradlePlugin: '8.5.2'").replace("androidGradlePlugin: '8.4.2'", "androidGradlePlugin: '8.5.2'").replace("kotlinVersion      : '1.9.20'", "kotlinVersion      : '1.9.24'")
    config.write_text(text)
    settings = BUILD / "settings.gradle"
    text = settings.read_text()
    if 'rootProject.name = "CourtyardWeather"' not in text:
        settings.write_text(text+'\nrootProject.name = "CourtyardWeather"\n')
    (BUILD/"local.properties").write_text("sdk.dir="+str(SDK)+"\n")
    manifest = BUILD/"AndroidManifest.xml"
    text = manifest.read_text().replace('android:screenOrientation="landscape"', 'android:screenOrientation="portrait"').replace('android:icon="@mipmap/icon"', 'android:icon="@drawable/companion_icon"')
    if 'android.permission.INTERNET' not in text:
        text = text.replace('    <supports-screens', '    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />\n\n    <supports-screens')
    manifest.write_text(text)
    text = manifest.read_text()
    if 'android.permission.ACCESS_COARSE_LOCATION' not in text:
        text = text.replace('    <supports-screens', '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n    <supports-screens')
    if 'org.godotengine.plugin.v2.CompanionLocation' not in text:
        text = text.replace('        <profileable', '        <meta-data android:name="org.godotengine.plugin.v2.CompanionLocation" android:value="com.weather.companion.CompanionLocation" />\n        <profileable')
    if 'android.permission.REQUEST_INSTALL_PACKAGES' not in text:
        text = text.replace('    <supports-screens', '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n    <supports-screens')
    if 'org.godotengine.plugin.v2.CompanionUpdater' not in text:
        text = text.replace('        <profileable', '        <meta-data android:name="org.godotengine.plugin.v2.CompanionUpdater" android:value="com.weather.companion.CompanionUpdater" />\n        <profileable')
    text = text.replace('android:name="androidx.core.content.FileProvider"', 'android:name="com.weather.companion.UpdateFileProvider"')
    if 'com.weather.companion.UpdateFileProvider' not in text:
        provider = '''        <provider android:name="com.weather.companion.UpdateFileProvider"
            android:authorities="com.weather.companion.updates" android:exported="false" android:grantUriPermissions="true">
            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/update_paths" />
        </provider>
'''
        text = text.replace('    </application>', provider+'    </application>')
    manifest.write_text(text)
    (BUILD/"res/xml").mkdir(exist_ok=True)
    (BUILD/"res/xml/update_paths.xml").write_text('<paths xmlns:android="http://schemas.android.com/apk/res/android"><cache-path name="updates" path="updates/" /></paths>')
    native = BUILD / "src/com/weather/companion"
    native.mkdir(parents=True, exist_ok=True)
    for kotlin in (PROJECT/"companion/android").glob("*.kt"):
        shutil.copy2(kotlin, native/kotlin.name)
    for name in (BUILD/"res").glob("values*/godot_project_name_string.xml"):
        name.write_text('<?xml version="1.0" encoding="utf-8"?><resources><string name="godot_project_name_string">小院天气</string></resources>')
    (BUILD/"res/drawable").mkdir(exist_ok=True)
    shutil.copy2(PROJECT/"companion/art/icon.png", BUILD/"res/drawable/companion_icon.png")
    pack = OUTPUT/"game_resources.pck"
    run([GODOT,"--headless","--path",PROJECT,"--export-pack","Companion Android",pack])
    if not pack.exists() or pack.stat().st_size < 100000:
        raise RuntimeError("Godot resource export incomplete")
    # Smoke-test the exported pack in isolation: editor success does not guarantee
    # that dynamically referenced scripts and JSON reached the APK.
    with tempfile.TemporaryDirectory(prefix="weather-pack-check-") as isolated:
        check = subprocess.run([str(GODOT), "--headless", "--path", isolated,
                                "--main-pack", str(pack), "--quit-after", "3"],
                               capture_output=True, text=True, timeout=60)
        print(check.stdout, check.stderr)
        if check.returncode or "ERROR:" in check.stdout + check.stderr:
            raise RuntimeError("Exported pack failed isolated startup check")
    # Android loads project.binary and resources directly from AssetManager.
    # A PCK copied into assets is not automatically mounted by the template.
    assets = BUILD / "assets"
    if assets.exists():
        shutil.rmtree(assets)
    assets.mkdir()
    with tempfile.TemporaryDirectory(prefix="weather-android-assets-") as temp:
        archive_path = Path(temp) / "resources.zip"
        run([GODOT, "--headless", "--path", PROJECT, "--export-pack",
             "Companion Android", archive_path])
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(assets)
    if not (assets / "project.binary").is_file():
        raise RuntimeError("Android project.binary missing")
    run([gradles[0],"--offline","--no-daemon","--max-workers=2","assembleStandardDebug",
         "-Pexport_enabled_abis=arm64-v8a", "-Pexport_package_name=com.weather.companion",
         f"-Pexport_version_code={VERSION_CODE}", f"-Pexport_version_name={VERSION_NAME}",
         "-Pgodot_rendering_method=gl_compatibility"], BUILD)
    raw = BUILD/"build/outputs/apk/standard/debug/android_debug.apk"
    tools = SDK/"build-tools/35.0.0"
    aligned = OUTPUT/"companion-aligned.apk"
    final = OUTPUT/"WeatherCompanion.apk"
    run([tools/"zipalign","-p","-f","4",raw,aligned])
    run([tools/"apksigner","sign","--ks",Path.home()/".android/debug.keystore",
         "--ks-pass","pass:android","--key-pass","pass:android","--ks-key-alias","androiddebugkey","--out",final,aligned])
    run([tools/"apksigner","verify",final])
    aligned.unlink()
    pack.unlink()
    print("APK_READY", final, final.stat().st_size, flush=True)

if __name__ == "__main__":
    main()
