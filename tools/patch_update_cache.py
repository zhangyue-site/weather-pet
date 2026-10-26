#!/usr/bin/env python3
"""Bind the verified native updater's temporary files to the manifest SHA256."""
import argparse,hashlib,json,re,subprocess,tempfile,zipfile
from pathlib import Path
BASE_SHA='b4cefabd459f42c7196fb785ffca71025faa9d927f4ad836fd848e4e3e097702'
def require(value,message):
    if not value: raise ValueError(message)
def canonical(text):
    def method(match):
        s=match.group();labels=re.findall(r'(?m)^\s*(:[A-Za-z0-9_]+)\s*$',s);names={label:':label_'+str(i) for i,label in enumerate(labels)}
        return re.sub(r':[A-Za-z0-9_]+',lambda m:names.get(m.group(),m.group()),s)
    normalized=re.sub(r'(?ms)^\.method .*?^\.end method',method,text)
    return '\n'.join(line.strip() for line in normalized.splitlines() if line.strip())
def patch(base,baksmali,smali,output):
    require(hashlib.sha256(base.read_bytes()).hexdigest()==BASE_SHA,'Unverified baseline')
    with tempfile.TemporaryDirectory(prefix='courtyard-cache-') as folder:
        root=Path(folder);original=root/'original.dex'
        with zipfile.ZipFile(base) as archive:original.write_bytes(archive.read('classes5.dex'))
        before=root/'before';after=root/'after'
        subprocess.run(['java','-jar',str(baksmali),'d','--sequential-labels',str(original),'-o',str(before)],check=True,capture_output=True)
        target=before/'com/weather/companion/ResumeDownloader.smali';text=target.read_text()
        for suffix in ['part','apk']:
            old='    const-string v14, "update.'+suffix+'"'
            require(text.count(old)==1,'Unexpected updater cache path')
            new='''    const-string v14, "sha256"
    invoke-virtual {v0, v14}, Lorg/json/JSONObject;->getString(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v14
    const-string v15, "[0-9a-fA-F]{64}"
    invoke-virtual {v14, v15}, Ljava/lang/String;->matches(Ljava/lang/String;)Z
    move-result v15
    if-nez v15, :valid_hash_SUFFIX
    new-instance v14, Ljava/lang/IllegalArgumentException;
    const-string v15, "Invalid update hash"
    invoke-direct {v14, v15}, Ljava/lang/IllegalArgumentException;-><init>(Ljava/lang/String;)V
    throw v14
    :valid_hash_SUFFIX
    const-string v15, ".SUFFIX"
    invoke-virtual {v14, v15}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v14'''.replace('SUFFIX',suffix)
            text=text.replace(old,new)
        target.write_text(text)
        expected={p.relative_to(before).as_posix():canonical(p.read_text()) for p in before.rglob('*.smali')}
        output.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['java','-jar',str(smali),'a','--api','21',str(before),'-o',str(output)],check=True,capture_output=True)
        require(output.read_bytes()[:8]==original.read_bytes()[:8],'DEX version changed')
        subprocess.run(['java','-jar',str(baksmali),'d','--sequential-labels',str(output),'-o',str(after)],check=True,capture_output=True)
        actual={p.relative_to(after).as_posix():canonical(p.read_text()) for p in after.rglob('*.smali')}
        require(actual==expected,'Unexpected semantic changes in rebuilt downloader')
        return {'dex':'classes5.dex','sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'classes_verified':len(expected),'change':'SHA256-bound cache names with strict 64-hex validation; original download and verification instructions preserved'}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['base','baksmali','smali','output']:parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();print(json.dumps(patch(args.base,args.baksmali,args.smali,args.output)))
