#!/usr/bin/env python3
"""Reject iOS exports that retain the legacy UIKit launch lifecycle."""
from pathlib import Path
import argparse,plistlib

def verify(app, check_private_paths=True):
    info=plistlib.loads((app/'Info.plist').read_bytes())
    manifest=info.get('UIApplicationSceneManifest',{})
    configurations=manifest.get('UISceneConfigurations',{}).get('UIWindowSceneSessionRoleApplication',[])
    if not any(c.get('UISceneDelegateClassName')=='GodotSceneDelegate' for c in configurations):
        raise ValueError('Missing UIKit scene configuration: iOS 27 rejects legacy launch')
    if manifest.get('UIApplicationSupportsMultipleScenes') is not False:
        raise ValueError('Courtyard must retain a single scene')
    binary = (app/info['CFBundleExecutable']).read_bytes()
    if check_private_paths and b'/Users/' in binary: raise ValueError('Native executable contains local build paths')
    if b'GodotSceneDelegate\0' not in binary:
        raise ValueError('Scene delegate is not linked in the actual executable')
    print('PASS iOS scene manifest and linked delegate')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('app',type=Path);args=parser.parse_args();verify(args.app)
