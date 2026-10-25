#!/usr/bin/env python3
"""Reject a PCK that omits raw fish frames, their manifest, or license."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def entries(pack):
    with pack.open("rb") as f:
        magic, version = struct.unpack("<II", f.read(8))
        if magic != 0x43504447 or version != 2:
            raise ValueError("Expected an unencrypted Godot 4 PCK v2")
        f.seek(20)
        flags, base = struct.unpack("<IQ", f.read(12))
        if flags & 1:
            raise ValueError("Encrypted directory is not supported by this audit")
        f.seek(96)
        count, = struct.unpack("<I", f.read(4))
        result = {}
        for _ in range(count):
            length, = struct.unpack("<I", f.read(4))
            path = f.read(length).rstrip(b"\0").decode()
            offset, size = struct.unpack("<QQ", f.read(16))
            md5 = f.read(16).hex()
            entry_flags, = struct.unpack("<I", f.read(4))
            result[path.removeprefix("res://")] = (base + offset, size, md5, entry_flags)
        return result


def verify(pack, project):
    table = entries(pack)
    base = project / "companion/fish"
    manifest = json.loads((base / "manifest.json").read_text())
    expected = [base / name / f"f{index:03d}.webp" for name, info in manifest.items() for index in range(info["frames"])]
    expected += [base / "manifest.json", base / "LICENSE-upstream.txt"]
    missing, mismatched = [], []
    with pack.open("rb") as f:
        for path in expected:
            resource = path.relative_to(project).as_posix()
            if resource not in table:
                missing.append(resource)
                continue
            offset, size, md5, flags = table[resource]
            f.seek(offset)
            data = f.read(size)
            if flags or hashlib.md5(data).hexdigest() != md5 or hashlib.sha256(data).digest() != hashlib.sha256(path.read_bytes()).digest():
                mismatched.append(resource)
    report = {"files": len(table), "fish_frames": len(expected) - 2,
              "missing": missing, "mismatched": mismatched,
              "sha256": hashlib.sha256(pack.read_bytes()).hexdigest()}
    print(json.dumps({**report, "missing": missing[:10], "mismatched": mismatched[:10]}, ensure_ascii=False))
    if missing or mismatched:
        raise SystemExit("Incomplete or corrupt animation pack")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "godot_project")
    args = parser.parse_args()
    verify(args.pack.resolve(), args.project.resolve())
