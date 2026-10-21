#!/usr/bin/env python3
"""Prepare an OTA release; --deploy publishes only after normal HTTPS validation.
No server credentials or signing keys are uploaded. Uses the user's existing SSH alias.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,tempfile,urllib.request,zipfile,shlex
ROOT=Path(__file__).resolve().parents[1]
BASE='https://zz.zhangyue.site/weather-companion'
REMOTE='/www/wwwroot/zz.zhangyue.site/weather-companion'
SDK=Path.home()/'Library/Android/sdk/build-tools/35.0.0'
def run(args,**kwargs):return subprocess.run([str(x) for x in args],check=True,**kwargs)
def prepare(apk,notes):
 run([SDK/'apksigner','verify',apk],capture_output=True)
 badging=run([SDK/'aapt','dump','badging',apk],capture_output=True,text=True).stdout
 package=re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'",badging)
 if not package or package[1]!='com.weather.companion':raise ValueError('Wrong package')
 sdk=re.search(r"sdkVersion:'(\d+)'",badging)
 abi=re.search(r"native-code: '([^']+)'",badging)
 if not sdk or not abi or abi[1]!='arm64-v8a':raise ValueError('Unexpected APK requirements')
 with zipfile.ZipFile(apk) as z:
  assets=ROOT/'godot_project/.companion_build/assets'
  for resource in assets.rglob('*'):
   if resource.is_file() and z.read('assets/'+resource.relative_to(assets).as_posix()) != resource.read_bytes():raise ValueError('APK assets do not match current export')
  if 'assets/project.binary' not in z.namelist():raise ValueError('Android startup resources missing')
 return {'schema':1,'package':package[1],'version_code':int(package[2]),'version_name':package[3], 'url':BASE+'/releases/WeatherCompanion-'+package[2]+'.apk','sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'bytes':apk.stat().st_size,'abi':abi[1],'min_sdk':int(sdk[1]),'notes':notes}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--deploy',action='store_true');args=parser.parse_args()
 apk=ROOT/'builds/WeatherCompanion.apk'
 info=prepare(apk,'全年每日主题；农历、节气与个人纪念日；200 套程序特效；应用内检查、下载并安装更新。')
 out=ROOT/'builds/latest.json';out.write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 build_info={'file':apk.name,'package':info['package'],'version':info['version_name'],'version_code':info['version_code'],'abi':info['abi'],'signing':'local debug','sha256':info['sha256'],'bytes':info['bytes'],'android_assets_verified':True}
 (ROOT/'builds/build-info.json').write_text(json.dumps(build_info,ensure_ascii=False,indent=2)+'\n')
 print('PREPARED',out,info['version_name'])
 if not args.deploy:return
 # TLS must be valid before any publication. An expired certificate is never bypassed.
 with urllib.request.urlopen('https://zz.zhangyue.site/',timeout=20) as r:r.read(1024)
 ssh=['ssh','-o','BatchMode=yes','-o','ConnectTimeout=10','wo_fuwuqi']
 run(ssh+['mkdir -p '+shlex.quote(REMOTE+'/releases')])
 name='WeatherCompanion-'+str(info['version_code'])+'.apk'
 for local,remote in [(apk,REMOTE+'/releases/'+name+'.part'),(out,REMOTE+'/latest.json.part'),(ROOT/'godot_project/companion/content/events.json',REMOTE+'/events.json.part')]:
  run(['scp','-q',local,'wo_fuwuqi:'+remote])
 script=f'''import hashlib,json,os
root={REMOTE!r}
p=root+'/releases/{name}.part'
assert hashlib.sha256(open(p,'rb').read()).hexdigest()=={info['sha256']!r}
assert os.path.getsize(p)=={info['bytes']}
for f in ['latest.json','events.json']:json.load(open(root+'/'+f+'.part'))
os.chmod(p,0o644)
os.replace(p,root+'/releases/{name}')
for f in ['events.json','latest.json']:
 os.chmod(root+'/'+f+'.part',0o644)
 os.replace(root+'/'+f+'.part',root+'/'+f)
print('PUBLISHED')
'''
 run(ssh+['python3 -'],input=script,text=True)
 with urllib.request.urlopen(BASE+'/latest.json',timeout=20) as r: live=json.load(r)
 if live!=info:raise ValueError('Published manifest does not match')
 with urllib.request.urlopen(info['url'],timeout=60) as r:
  digest=hashlib.sha256();total=0
  while chunk:=r.read(1024*1024):digest.update(chunk);total+=len(chunk)
 assert total==info['bytes'] and digest.hexdigest()==info['sha256']
 print('HTTPS release verified',BASE+'/latest.json')
if __name__=='__main__':main()
