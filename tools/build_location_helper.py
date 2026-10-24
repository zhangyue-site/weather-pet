#!/usr/bin/env python3
"""Compile the standalone Android geocoder helper; never include the test class in DEX."""
from pathlib import Path
import argparse,subprocess,zipfile,os,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser()
 p.add_argument('--android-jar',type=Path,required=True);p.add_argument('--d8',type=Path,required=True)
 p.add_argument('--out',type=Path,required=True);p.add_argument('--javac',default='javac');p.add_argument('--java',default='java');p.add_argument('--test',action='store_true')
 a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);classes=a.out/'classes';classes.mkdir(exist_ok=True)
 sources=[ROOT/'godot_project/companion/android/LocationNameResolver.java']
 if a.test:sources.append(ROOT/'tools/android_location_test/LocationNameResolverTest.java')
 subprocess.run([a.javac,'-encoding','UTF-8','--release','8','-cp',str(a.android_jar),'-d',str(classes),*[str(s) for s in sources]],check=True)
 if a.test:subprocess.run([a.java,'-cp',str(classes)+os.pathsep+str(a.android_jar),'com.weather.companion.LocationNameResolverTest'],check=True,timeout=5)
 jar=a.out/'location-helper.jar'
 with zipfile.ZipFile(jar,'w',zipfile.ZIP_DEFLATED) as z:
  for f in classes.rglob('*.class'):
   if f.name=='LocationNameResolver.class' or f.name.startswith('LocationNameResolver$'):z.write(f,str(f.relative_to(classes)))
 with zipfile.ZipFile(jar) as z:
  if not z.namelist() or any('Test' in n for n in z.namelist()):raise ValueError('invalid production helper contents')
 dex=a.out/'dex';dex.mkdir(exist_ok=True)
 subprocess.run([str(a.d8),'--min-api','21','--lib',str(a.android_jar),'--output',str(dex),str(jar)],check=True)
 data=(dex/'classes.dex').read_bytes()
 if not data.startswith(b'dex\n'):raise ValueError('not a DEX file')
 print(json.dumps({'dex':str(dex/'classes.dex'),'sha256':hashlib.sha256(data).hexdigest(),'native_tests_passed':a.test}))
if __name__=='__main__':main()
