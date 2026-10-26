#!/usr/bin/env python3
"""Run shared regressions with bounded execution and isolated Godot user storage."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot_project'
ENGINE = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')

def main():
    failed = []
    logs = ROOT / '.local/qa/tests'
    logs.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='courtyard-tests-') as temporary:
        project = Path(temporary)
        for item in PROJECT.iterdir():
            if item.name != 'project.godot':
                (project / item.name).symlink_to(item.resolve(), target_is_directory=item.is_dir())
        config = (PROJECT / 'project.godot').read_text()
        config = re.sub(r'config/name="[^"]*"', 'config/name="Courtyard QA ' + uuid.uuid4().hex + '"', config)
        (project / 'project.godot').write_text(config)
        for test in sorted((PROJECT / 'tests').glob('test_*.gd')):
            try:
                result = subprocess.run([ENGINE, '--headless', '--path', str(project),
                    '--script', 'res://tests/' + test.name, '--quit-after', '900'],
                    capture_output=True, text=True, timeout=40)
                output = result.stdout + result.stderr
                passed = result.returncode == 0 and 'PASS' in output and not re.search(r'FAIL|SCRIPT ERROR|ERROR:', output)
            except subprocess.TimeoutExpired as error:
                output = str(error); passed = False
            (logs / (test.stem + '.log')).write_text(output)
            print(('PASS ' if passed else 'FAIL ') + test.name, flush=True)
            if not passed:
                failed.append(test.name)
                print(output[:3500], flush=True)
    print(f'{len(list((PROJECT / "tests").glob("test_*.gd"))) - len(failed)} passed; {len(failed)} failed', flush=True)
    return bool(failed)

if __name__ == '__main__':
    raise SystemExit(main())
