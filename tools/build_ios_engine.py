#!/usr/bin/env python3
"""Build Godot 4.4.1 iOS with the UIKit scene lifecycle required by iOS 27."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BEFORE="a080de938b6cd0b763ed452803d8f9a350a71b85a018a052e7c908bef7248a67"
AFTER="7758c8cb6b1341cbc25caee7223cb76e9674fa65fbfcdf27c1b7a5771c3d7d17"
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot-source',type=Path,required=True);p.add_argument('--scons',default='scons');p.add_argument('--simulator',action='store_true');p.add_argument('--jobs',type=int,default=8);args=p.parse_args()
    source=args.godot_source.resolve();version=(source/'version.py').read_text()
    if not all(re.search(r'^'+name+r' = '+str(value)+r'$',version,re.M) for name,value in [('major',4),('minor',4),('patch',1)]):raise SystemExit('Use the matching Godot 4.4.1 source')
    delegate=source/'platform/ios/app_delegate.mm';digest=hashlib.sha256(delegate.read_bytes()).hexdigest()
    if digest==BEFORE:subprocess.run(['patch','-p1','-i',str(ROOT/'native/ios/godot-4.4.1-scene-lifecycle.patch')],cwd=source,check=True)
    elif digest!=AFTER:raise SystemExit('Unexpected AppDelegate source; refusing to overwrite')
    if hashlib.sha256(delegate.read_bytes()).hexdigest()!=AFTER:raise SystemExit('Scene lifecycle patch does not match reviewed source')
    subprocess.run([args.scons,'platform=ios','target=template_release','arch=arm64','ios_simulator='+('yes' if args.simulator else 'no'),'metal=no','vulkan=no','disable_3d=yes','optimize=size','-j'+str(args.jobs)],cwd=source,check=True)
    engine=source/('bin/libgodot.ios.template_release.arm64'+('.simulator' if args.simulator else '')+'.a')
    symbols=subprocess.check_output(['nm','-gU',str(engine)],stderr=subprocess.DEVNULL)
    if b'_OBJC_CLASS_$_GodotSceneDelegate' not in symbols:raise SystemExit('Scene delegate not linked in engine')
    print(json.dumps({'engine':str(engine),'scene_lifecycle':True,'sha256':hashlib.sha256(engine.read_bytes()).hexdigest()}))
if __name__=='__main__':main()
