#!/usr/bin/env python3
"""Build the iOS singleton against the same Godot 4.4.1 headers as the template."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-source", type=Path, required=True)
    parser.add_argument("--scons", default="scons")
    parser.add_argument("--build-dir", type=Path, default=ROOT / ".local/ios-native")
    args = parser.parse_args()
    source = args.godot_source.resolve()
    version = (source / "version.py").read_text()
    if 'major = 4' not in version or 'minor = 4' not in version or 'patch = 1' not in version:
        raise SystemExit("The plugin requires the official Godot 4.4.1 source and templates")
    scons = str(Path(args.scons).resolve()) if Path(args.scons).is_file() else args.scons
    if not all((source / header).is_file() for header in ["core/object/gdvirtual.gen.inc", "core/disabled_classes.gen.h"]):
        run([scons, "platform=ios", "target=template_release", "arch=arm64",
             "core/object/gdvirtual.gen.inc", "core/disabled_classes.gen.h"], cwd=source)
    build = args.build_dir.resolve()
    build.mkdir(parents=True, exist_ok=True)
    libraries = []
    for sdk, arch, target in [("iphoneos", "arm64", "arm64-apple-ios15.0"),
                              ("iphonesimulator", "arm64", "arm64-apple-ios15.0-simulator"),
                              ("iphonesimulator", "x86_64", "x86_64-apple-ios15.0-simulator")]:
        folder = build / (sdk + "-" + arch)
        folder.mkdir(exist_ok=True)
        sysroot = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        obj = folder / "CompanionIOS.o"
        run(["xcrun", "--sdk", sdk, "clang++", "-c", ROOT / "native/ios/CompanionIOS.mm",
             "-o", obj, "-target", target, "-isysroot", sysroot, "-std=c++17", "-O2",
             "-ffile-prefix-map=" + str(source) + "=godot",
             "-ffile-prefix-map=" + str(ROOT) + "=courtyard",
             "-fobjc-arc", "-fmodules", "-fcxx-modules", "-fno-exceptions",
             "-DIOS_ENABLED", "-DUNIX_ENABLED", "-DPTRCALL_ENABLED", "-DNDEBUG",
             "-I", source, "-I", source / "platform/ios"])
        library = folder / "libCompanionIOS.a"
        run(["xcrun", "libtool", "-static", "-o", library, obj])
        if sdk == "iphoneos": libraries += ["-library", library]
    simulator = build / "libCompanionIOS-simulator.a"
    run(["xcrun", "lipo", "-create", build / "iphonesimulator-arm64/libCompanionIOS.a",
         build / "iphonesimulator-x86_64/libCompanionIOS.a", "-output", simulator])
    libraries += ["-library", simulator]
    output = ROOT / "godot_project/ios/plugins/companion/CompanionIOS.xcframework"
    if output.exists():
        shutil.rmtree(output)
    run(["xcodebuild", "-create-xcframework", *libraries, "-output", output])


if __name__ == "__main__":
    main()
