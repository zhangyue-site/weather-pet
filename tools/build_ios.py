#!/usr/bin/env python3
"""Export the shared Godot courtyard, verify assets, build and optionally sign an IPA."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

from verify_pack import verify

ROOT = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--output", type=Path, default=ROOT / "builds/ios")
    parser.add_argument("--simulator", action="store_true")
    parser.add_argument("--template", type=Path, default=Path.home() / "Library/Application Support/Godot/export_templates/4.4.1.stable/ios.zip")
    parser.add_argument("--identity", default=os.environ.get("IOS_SIGN_IDENTITY"))
    parser.add_argument("--profile", type=Path, default=os.environ.get("IOS_PROVISIONING_PROFILE"))
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.4.1."):
        raise SystemExit("Use the same Godot 4.4.1 editor, source headers and iOS template")
    plugin = ROOT / "godot_project/ios/plugins/companion/CompanionIOS.xcframework"
    if not plugin.is_dir():
        raise SystemExit("Build the native plugin with tools/build_ios_plugin.py first")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # A portable editor avoids touching the user's editor settings or probing their
    # connected Android devices from the iOS-only export process.
    editor_dir = ROOT / ".local/ios-editor"
    editor_dir.mkdir(parents=True, exist_ok=True)
    editor = editor_dir / "Godot"
    if not editor.exists():
        try:
            os.link(Path(args.godot).resolve(), editor)
        except OSError:
            shutil.copy2(args.godot, editor)
    (editor_dir / "_sc_").touch()
    templates = editor_dir / "editor_data/export_templates/4.4.1.stable"
    templates.mkdir(parents=True, exist_ok=True)
    if not args.template.is_file():
        raise SystemExit("Install the official Godot 4.4.1 iOS template, or supply --template")
    template_link = templates / "ios.zip"
    if template_link.is_symlink(): template_link.unlink()
    if not template_link.exists(): template_link.symlink_to(args.template.resolve())
    (editor_dir / "editor_data/editor_settings-4.4.tres").write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        'export/android/android_sdk_path = "/nonexistent/courtyard-ios-only"\n'
        'export/android/shutdown_adb_on_exit = false\n')
    run([editor, "--headless", "--path", ROOT / "godot_project", "--export-release",
         "Companion iOS", output / "Courtyard.ipa", "--quit"],
        env={**os.environ, "ANDROID_HOME": "/nonexistent/courtyard-ios-only"})
    audit = verify(output / "Courtyard.pck", ROOT / "godot_project")
    sdk = "iphonesimulator" if args.simulator else "iphoneos"
    if args.simulator:
        # MetalFX is device-only in recent Apple SDKs. Godot's simulator engine
        # does not use it, but the 4.4.1 Xcode template still weak-links it.
        project_file = output / "Courtyard.xcodeproj/project.pbxproj"
        lines = project_file.read_text().splitlines()
        project_file.write_text("\n".join(line for line in lines if "/* MetalFX.framework in Frameworks */" not in line) + "\n")
    derived = output / "DerivedData"
    run(["xcodebuild", "-project", output / "Courtyard.xcodeproj", "-scheme", "Courtyard",
         "-configuration", "Release", "-sdk", sdk, "-derivedDataPath", derived,
         "CODE_SIGNING_ALLOWED=NO", "ARCHS=x86_64" if args.simulator else "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES",
         "COMPILER_INDEX_STORE_ENABLE=NO", "build"])
    app = derived / f"Build/Products/Release-{sdk}/Courtyard.app"
    if args.simulator:
        print(json.dumps({"simulator_app": str(app), "pack": audit}))
        return
    info = plistlib.loads((app / "Info.plist").read_bytes())
    signed = False
    if bool(args.identity) != bool(args.profile):
        raise SystemExit("Signing requires both --identity and --profile")
    if args.identity and args.profile:
        profile = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", args.profile]))
        entitlements = profile["Entitlements"]
        bundle = info["CFBundleIdentifier"]
        if entitlements.get("application-identifier") != profile["TeamIdentifier"][0] + "." + bundle:
            raise SystemExit("Provisioning profile does not match the app bundle identifier")
        shutil.copy2(args.profile, app / "embedded.mobileprovision")
        entitlement_file = output / "signing-entitlements.plist"
        entitlement_file.write_bytes(plistlib.dumps(entitlements))
        run(["codesign", "--force", "--sign", args.identity, "--entitlements", entitlement_file,
             "--generate-entitlement-der", app])
        run(["codesign", "--verify", "--deep", "--strict", app])
        signed = True
    suffix = "signed" if signed else "unsigned"
    ipa = output / f"Courtyard-{info['CFBundleShortVersionString']}-{info['CFBundleVersion']}-{suffix}.ipa"
    with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for item in app.rglob("*"):
            if item.is_file():
                archive.write(item, Path("Payload") / app.name / item.relative_to(app))
    metadata = {"version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
                "bundle": info["CFBundleIdentifier"], "signed": signed, "bytes": ipa.stat().st_size,
                "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(), "godot": version,
                "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "pack": audit, "ipa": str(ipa), "physical_device_tested": False}
    (output / "build-report.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2))
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
