#!/bin/bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
DEVICE="${ANDROID_SERIAL:?Set an isolated test device serial}"
JDK="${JAVA_HOME:-$(/usr/libexec/java_home)}"
BUILD="$(mktemp -d /tmp/weather-ota-checks.XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
mkdir "$BUILD/classes" "$BUILD/dex"
if [ -z "${OTA_TEST_APK:-}" ]; then
"$JDK/bin/javac" -source 8 -target 8 -classpath "$SDK/platforms/android-35/android.jar" -d "$BUILD/classes" "$SRC/OtaChecks.java"
"$JDK/bin/jar" cf "$BUILD/checks.jar" -C "$BUILD/classes" .
JAVA_HOME="$JDK" "$SDK/build-tools/35.0.0/d8" --lib "$SDK/platforms/android-35/android.jar" --output "$BUILD/dex" "$BUILD/checks.jar"
"$SDK/build-tools/35.0.0/aapt" package -f -M "$SRC/AndroidManifest.xml" -I "$SDK/platforms/android-35/android.jar" -F "$BUILD/checks.apk"
(cd "$BUILD/dex" && "$SDK/build-tools/35.0.0/aapt" add "$BUILD/checks.apk" classes.dex)
JAVA_HOME="$JDK" "$SDK/build-tools/35.0.0/apksigner" sign --ks "$HOME/.android/debug.keystore" --ks-pass pass:android "$BUILD/checks.apk"
else
cp "$OTA_TEST_APK" "$BUILD/checks.apk"
fi
"$SDK/platform-tools/adb" -s "$DEVICE" install -r "$BUILD/checks.apk"
"$SDK/platform-tools/adb" -s "$DEVICE" shell am instrument -w -e network "${OTA_NETWORK_TEST:-false}" -e good "${OTA_GOOD_PATH:-}" -e bad "${OTA_BAD_PATH:-}" com.weather.companion.tests/.OtaChecks | tee "$BUILD/result.txt"
grep -q "PASS native OTA" "$BUILD/result.txt"
"$SDK/platform-tools/adb" -s "$DEVICE" uninstall com.weather.companion.tests
