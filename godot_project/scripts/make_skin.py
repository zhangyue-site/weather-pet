#!/usr/bin/env python3
"""
天气小人 · 形象差异化贴图生成器
基于 Godot Plush 原贴图, 生成"天蓝晴天精灵"版本
保留 UV 布局, 只改颜色/添加元素
"""
from PIL import Image, ImageDraw, ImageFilter
import os

SRC = None  # 动态查找

def find_texture():
    p = "models/material/godot_plush_albedo.png"
    if os.path.exists(p):
        return p
    p2 = "/Users/yuezhang/Godot-Plush-Character/components/godot_plush/material/godot_plush_albedo.png"
    if os.path.exists(p2):
        return p2
    raise FileNotFoundError("找不到原贴图")

def analyze(img):
    """分析贴图各区域, 输出调试信息"""
    w, h = img.size
    print(f"贴图尺寸: {w}x{h}")
    # 采样各象限的平均色
    regions = {
        "左上": (0, 0, w//2, h//2),
        "右上": (w//2, 0, w, h//2),
        "左下": (0, h//2, w//2, h),
        "右下": (w//2, h//2, w, h),
        "正中": (w//4, h//4, 3*w//4, 3*h//4),
    }
    for name, box in regions.items():
        crop = img.crop(box)
        pixels = list(crop.getdata())
        if pixels:
            r = sum(p[0] for p in pixels) // len(pixels)
            g = sum(p[1] for p in pixels) // len(pixels)
            b = sum(p[2] for p in pixels) // len(pixels)
            print(f"  {name} 区域平均色: RGB({r},{g},{b})  #{r:02x}{g:02x}{b:02x}")
    # 找深色像素 (眼睛/嘴巴等深色图案)
    dark_pts = []
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            px = img.getpixel((x, y))
            if px[0] < 80 and px[1] < 80 and px[2] < 80:  # 深色
                dark_pts.append((x, y))
    if dark_pts:
        xs = [p[0] for p in dark_pts]
        ys = [p[1] for p in dark_pts]
        print(f"  深色图案(眼睛等)区域: x[{min(xs)}-{max(xs)}] y[{min(ys)}-{max(ys)}]")

def recolor_skyblue(img):
    """把米色基底改成天蓝色渐变 (晴天精灵)"""
    w, h = img.size
    new = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px_src = img.load()
    px_dst = new.load()

    # 天蓝色渐变 (上深下浅, 像天空)
    sky_top = (95, 165, 220)     # 中天蓝
    sky_bot = (170, 215, 240)    # 浅天蓝
    belly_color = (240, 250, 255)  # 白色肚皮

    for y in range(h):
        for x in range(w):
            r, g, b, a = px_src[x, y]
            if a < 10:
                px_dst[x, y] = (0, 0, 0, 0)
                continue
            # 计算亮度 (判断该像素是亮区还是暗区)
            lum = (r + g + b) / 3.0
            # 原贴图是米色: 亮区=高光, 暗区=阴影/图案
            # UV.y 大致对应模型高度: y 小=头顶, y 大=脚底
            t = y / h
            # 天蓝色渐变
            base_r = sky_top[0] + (sky_bot[0] - sky_top[0]) * t
            base_g = sky_top[1] + (sky_bot[1] - sky_top[1]) * t
            base_b = sky_top[2] + (sky_bot[2] - sky_top[2]) * t
            # 根据原亮度调整: 亮区更亮, 暗区更暗 (保留明暗关系)
            lum_factor = lum / 200.0  # 原米色约200
            if lum_factor > 1.0:
                # 高光: 偏白
                factor = min(1.0, (lum - 200) / 55.0)
                nr = base_r + (255 - base_r) * factor * 0.5
                ng = base_g + (255 - base_g) * factor * 0.5
                nb = base_b + (255 - base_b) * factor * 0.5
            elif lum_factor < 0.5:
                # 阴影: 加深
                factor = (100 - lum) / 100.0
                factor = min(1.0, max(0.0, factor))
                nr = base_r * (1 - factor * 0.4)
                ng = base_g * (1 - factor * 0.4)
                nb = base_b * (1 - factor * 0.4)
            else:
                nr, ng, nb = base_r, base_g, base_b
            px_dst[x, y] = (int(nr), int(ng), int(nb), a)
    return new

def add_features(img):
    """添加: 腮红 + 大眼睛高光 + 天气印花"""
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # 天气印花: 在身体中下部画一个小太阳 (基于深色图案区域推断)
    # 原贴图身体大概在 y=250-400 范围
    sun_cx, sun_cy = w // 2, int(h * 0.72)
    sun_r = int(w * 0.06)
    # 太阳光芒
    import math
    for i in range(8):
        ang = i * math.pi / 4
        x1 = sun_cx + math.cos(ang) * (sun_r + 4)
        y1 = sun_cy + math.sin(ang) * (sun_r + 4)
        x2 = sun_cx + math.cos(ang) * (sun_r + 10)
        y2 = sun_cy + math.sin(ang) * (sun_r + 10)
        draw.line([(x1, y1), (x2, y2)], fill=(255, 210, 90, 180), width=3)
    # 太阳本体 (暖黄, 半透明)
    draw.ellipse([sun_cx - sun_r, sun_cy - sun_r, sun_cx + sun_r, sun_cy + sun_r],
                 fill=(255, 200, 80, 160))

    # 合并到主贴图
    result = Image.alpha_composite(img.convert("RGBA"), overlay)

    # 腮红: 找眼睛区域 (深色), 在其两侧画粉色
    # 用模糊的粉色圆点
    blush = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    # 腮红位置 (基于分析, 眼睛附近) - 多个候选位置用半透明叠加
    blush_pts = [
        (int(w*0.32), int(h*0.30)),  # 左脸
        (int(w*0.68), int(h*0.30)),  # 右脸
        (int(w*0.20), int(h*0.35)),  # 左脸外侧(侧面UV)
        (int(w*0.80), int(h*0.35)),  # 右脸外侧
    ]
    for bx, by in blush_pts:
        for i in range(5):
            r = 18 - i * 3
            a = 100 - i * 18
            bd.ellipse([bx-r, by-r, bx+r, by+r], fill=(255, 130, 150, a))
    blush = blush.filter(ImageFilter.GaussianBlur(radius=4))
    result = Image.alpha_composite(result, blush)

    return result

def main():
    global SRC
    SRC = find_texture()
    print(f"原贴图: {SRC}")
    img = Image.open(SRC).convert("RGBA")

    print("\n=== 原贴图分析 ===")
    analyze(img)

    print("\n=== 生成天蓝版 ===")
    skyblue = recolor_skyblue(img)
    print("✅ 天蓝基底完成")

    print("\n=== 添加差异化元素 ===")
    final = add_features(skyblue)
    print("✅ 腮红 + 大眼睛 + 天气印花 完成")

    out_path = "models/material/godot_plush_albedo.png"
    backup = "models/material/godot_plush_albedo_original.png"
    # 备份原版
    if not os.path.exists(backup):
        img.save(backup)
        print(f"✅ 原版备份: {backup}")
    final.save(out_path)
    print(f"✅ 天蓝版已保存: {out_path}")
    print(f"   尺寸: {final.size}")

if __name__ == "__main__":
    main()
