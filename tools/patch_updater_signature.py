#!/usr/bin/env python3
"""Rebuild only the verified baseline updater DEX for Android 9 archive signatures."""
import argparse,hashlib,json,re,subprocess,tempfile,zipfile
from pathlib import Path
BASE_SHA='b4cefabd459f42c7196fb785ffca71025faa9d927f4ad836fd848e4e3e097702'
def require(value,message):
    if not value: raise ValueError(message)
def patch(base,baksmali,smali,output):
    require(hashlib.sha256(base.read_bytes()).hexdigest()==BASE_SHA,'Unverified baseline')
    with tempfile.TemporaryDirectory(prefix='courtyard-updater-') as folder:
        root=Path(folder);original=root/'original.dex'
        with zipfile.ZipFile(base) as archive:original.write_bytes(archive.read('classes3.dex'))
        before=root/'before';after=root/'after'
        subprocess.run(['java','-jar',str(baksmali),'d','--sequential-labels',str(original),'-o',str(before)],check=True,capture_output=True)
        target=before/'com/weather/companion/CompanionUpdater.smali';text=target.read_text()
        method=re.search(r'(?ms)^\.method private final verify\(.*?^\.end method',text);require(method is not None,'Updater method missing')
        body,count=re.subn(r'const/high16 (v\d+), 0x8000000',r'const \1, 0x8000040',method.group());require(count==1,'Expected one certificate query flag')
        target.write_text(text[:method.start()]+body+text[method.end():])
        expected={p.relative_to(before).as_posix():p.read_bytes() for p in before.rglob('*.smali')}
        output.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['java','-jar',str(smali),'a','--api','21',str(before),'-o',str(output)],check=True,capture_output=True)
        require(output.read_bytes()[:8]==original.read_bytes()[:8],'DEX version changed')
        subprocess.run(['java','-jar',str(baksmali),'d','--sequential-labels',str(output),'-o',str(after)],check=True,capture_output=True)
        actual={p.relative_to(after).as_posix():p.read_bytes() for p in after.rglob('*.smali')}
        require(actual==expected,'Unexpected semantic changes in rebuilt updater')
        return {'dex':'classes3.dex','sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'classes_verified':len(expected),'change':'verify requests GET_SIGNATURES together with GET_SIGNING_CERTIFICATES; signer equality and all other instructions preserved'}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['base','baksmali','smali','output']:parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();print(json.dumps(patch(args.base,args.baksmali,args.smali,args.output)))
