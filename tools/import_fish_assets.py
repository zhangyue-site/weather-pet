#!/usr/bin/env python3
"""Import pinned upstream transparent animations, preserving each complete clip."""
import concurrent.futures, hashlib, json, subprocess, urllib.parse, urllib.request
from pathlib import Path
REV = 'b292803d694e8820d6f1fc88101dec7a0b87cadc'
BASE = f'https://raw.githubusercontent.com/PC2005-cloud/dsh-pet/{REV}/'
ALIASES = {'待机呼吸休闲':'idle','原地漂浮踏步':'walk','超大伸懒腰':'stretch','点击回应-元气挥手':'wave','点击回应-挠痒咯咯笑':'pet','工作状态-雀跃庆祝':'cheer','可爱宅舞':'dance','被吓一跳':'scared','吃白饭':'drink','原地小憩沉眠':'sleep','哈欠连天':'cold','摇扇纳凉':'hot','东张西望':'notice','堆雪人':'snow','蝴蝶蜜蜂环绕头顶开花':'water','点击回应-开心跃动':'happy','鲸鱼吐泡泡特效':'umbrella','工作状态-垂头叹气冒汗':'shake'}
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/tmp/weather-fish-source')
DEST = ROOT/'godot_project/companion/fish'

def fetch(path, dest):
    if dest.exists() and dest.stat().st_size > 100: return
    with urllib.request.urlopen(BASE+urllib.parse.quote(path),timeout=60) as r: dest.write_bytes(r.read())

def convert(item):
    idx, path = item
    label = Path(path).stem
    name = ALIASES.get(label, f'full_{idx:03d}')
    src = SOURCE/Path(path).name
    fetch(path, src)
    out = DEST/name
    out.mkdir(parents=True, exist_ok=True)
    stamp = out/'source.sha256'
    sha = hashlib.sha256(src.read_bytes()).hexdigest()
    if not stamp.exists() or stamp.read_text()!=sha:
        for old in out.glob('f*.webp'): old.unlink()
        from PIL import Image
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height','-of','json',str(src)]))['streams'][0]
        w=round(probe['width']*304/probe['height']/2)*2
        proc=subprocess.Popen(['ffmpeg','-v','error','-threads','1','-c:v','libvpx-vp9','-i',str(src),'-an','-vf',f'fps=12,scale={w}:304:flags=lanczos,format=rgba','-f','rawvideo','-pix_fmt','rgba','pipe:1'],stdout=subprocess.PIPE)
        i=0
        while True:
            raw=proc.stdout.read(w*304*4)
            if not raw: break
            assert len(raw)==w*304*4
            Image.frombytes('RGBA',(w,304),raw).save(out/f'f{i:03d}.webp',quality=78,method=3)
            i+=1
        assert proc.wait()==0
        stamp.write_text(sha)
    frames = sorted(out.glob('f*.webp'))
    from PIL import Image
    with Image.open(frames[0]) as image:
        w,h=image.size
        assert 'A' in image.getbands(), label+' alpha missing'
        assert image.getextrema()[-1][0] == 0, label+' background not transparent'
    box=None
    for frame in frames:
        with Image.open(frame) as image: b=image.getchannel('A').getbbox()
        if b: box=b if box is None else (min(box[0],b[0]),min(box[1],b[1]),max(box[2],b[2]),max(box[3],b[3]))
    return name, {'label':label,'fps':12,'frames':len(frames),'w':w,'h':h,'duration':len(frames)/12,'crop':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'source':path,'sha256':sha}

def main():
    SOURCE.mkdir(exist_ok=True); DEST.mkdir(exist_ok=True)
    tree=json.loads(subprocess.check_output(['gh','api',f'repos/PC2005-cloud/dsh-pet/git/trees/{REV}?recursive=1']))
    paths=sorted(x['path'] for x in tree['tree'] if x['path'].startswith('dsh-pet/assets/webm/') and x['path'].endswith('.webm'))
    manifest={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for name,info in pool.map(convert,enumerate(paths)):
            manifest[name]=info
            print(name,info['label'],info['frames'],flush=True)
    assert len(manifest)==106 and set(ALIASES.values()) <= set(manifest)
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    fetch('LICENSE',DEST/'LICENSE-upstream.txt')
    (DEST/'README.md').write_text(f'# 大肥鱼透明动画\n\n来源：https://github.com/PC2005-cloud/dsh-pet\n\n固定提交：{REV}，MIT，完整许可见LICENSE-upstream.txt。\n106个原始WebM按完整时长转换为12fps/304高透明WebP；旧18个动作ID保留兼容别名。manifest记录中文名称、原路径、原文件SHA256与帧数。\n')
    print('DONE',len(manifest),sum(x['frames'] for x in manifest.values()),flush=True)
if __name__=='__main__': main()
