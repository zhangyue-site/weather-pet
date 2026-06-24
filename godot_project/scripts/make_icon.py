#!/usr/bin/env python3
"""
天气小人 v2 - 应用图标生成器
绘制一个圆滚滚的可爱小人 + 天气元素(太阳/云), 匹配项目 pet_renderer.gd 造型
输出: Godot icon.png + Android 各分辨率 mipmap 图标
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

# ---------- 颜色定义 (对齐 pet_renderer.gd) ----------
BG_TOP = (44, 53, 92)       # 深蓝渐变顶 (天空感)
BG_BOTTOM = (120, 165, 210) # 浅蓝渐变底
BODY = (243, 243, 158)       # 小人身体黄 (0.95, 0.95, 0.65 → ~243,243,166)
BODY_LIGHT = (255, 255, 220)
BODY_DARK = (180, 165, 90)
EAR_INNER = (240, 160, 160)
EYE = (30, 25, 30)
EYE_HL = (255, 255, 255)
BLUSH = (255, 150, 150)
MOUTH = (140, 70, 70)
SUN = (255, 200, 70)
SUN_RAY = (255, 220, 110)
CLOUD = (255, 255, 255)
SHADOW = (0, 0, 0, 60)


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def gradient_bg(size):
    """垂直渐变背景"""
    w, h = size
    bg = Image.new("RGBA", size, (0, 0, 0, 0))
    px = bg.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = lerp_color(BG_TOP, BG_BOTTOM, t)
        for x in range(w):
            px[x, y] = (c[0], c[1], c[2], 255)
    return bg


def rounded_rect(d, box, radius, **kw):
    d.rounded_rectangle(box, radius=radius, **kw)


def draw_sun(img, cx, cy, r):
    """太阳 (带光芒)"""
    d = ImageDraw.Draw(img, "RGBA")
    # 光芒
    for i in range(12):
        a = i * math.pi / 6
        x1 = cx + math.cos(a) * (r + r * 0.35)
        y1 = cy + math.sin(a) * (r + r * 0.35)
        x2 = cx + math.cos(a) * (r + r * 0.7)
        y2 = cy + math.sin(a) * (r + r * 0.7)
        d.line([(x1, y1), (x2, y2)], fill=SUN_RAY + (230,), width=max(2, int(r * 0.18)))
    # 光晕
    for i in range(4):
        gr = r + r * (0.15 + i * 0.12)
        alpha = 40 - i * 9
        d.ellipse([cx - gr, cy - gr, cx + gr, cy + gr], fill=(255, 220, 130, alpha))
    # 太阳本体
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN)
    # 高光
    hr = r * 0.35
    d.ellipse([cx - r * 0.4 - hr, cy - r * 0.4 - hr,
               cx - r * 0.4 + hr, cy - r * 0.4 + hr], fill=(255, 245, 200))


def draw_cloud(img, cx, cy, s):
    """白云"""
    d = ImageDraw.Draw(img, "RGBA")
    # 阴影
    d.ellipse([cx - 30 * s, cy - 12 * s + 3, cx + 30 * s, cy + 12 * s + 3],
              fill=(0, 0, 0, 35))
    # 多个圆组成云
    d.ellipse([cx - 30 * s, cy - 14 * s, cx - 6 * s, cy + 14 * s], fill=CLOUD)
    d.ellipse([cx - 14 * s, cy - 20 * s, cx + 16 * s, cy + 10 * s], fill=CLOUD)
    d.ellipse([cx + 2 * s, cy - 12 * s, cx + 30 * s, cy + 14 * s], fill=CLOUD)
    d.ellipse([cx - 16 * s, cy - 4 * s, cx + 18 * s, cy + 12 * s], fill=CLOUD)
    # 顶部高光
    d.ellipse([cx - 10 * s, cy - 16 * s, cx + 6 * s, cy - 4 * s],
              fill=(255, 255, 255, 220))


def draw_pet(img, cx, cy, scale):
    """天气小人主体 - 匹配 pet_renderer.gd 造型"""
    d = ImageDraw.Draw(img, "RGBA")
    s = scale

    # ---- 地面阴影 ----
    sw, sh = 80 * s, 14 * s
    d.ellipse([cx - sw, cy + 95 * s - sh, cx + sw, cy + 95 * s + sh],
              fill=(0, 0, 0, 70))

    # ---- 身体 (圆角矩形) ----
    bw, bh = 95 * s, 110 * s
    bx0, by0 = cx - bw / 2, cy + 18 * s
    # 身体渐变 (用多层椭圆模拟)
    for i in range(8):
        t = i / 7
        c = lerp_color(BODY_LIGHT, BODY_DARK, t * 0.9)
        seg_h = bh / 8
        d.rounded_rectangle(
            [bx0, by0 + i * seg_h, bx0 + bw, by0 + (i + 1) * seg_h + 1],
            radius=22 * s, fill=c)
    # 主色覆盖
    d.rounded_rectangle([bx0, by0, bx0 + bw, by0 + bh], radius=22 * s,
                        fill=None, outline=BODY_DARK, width=2)

    # ---- 头 (大圆) ----
    hr = 52 * s
    hy = cy - 30 * s
    # 头部渐变
    for i in range(10):
        t = i / 9
        rr = max(1.0, hr - i * 1.5)
        c = lerp_color(BODY_LIGHT, BODY, t)
        d.ellipse([cx - rr, hy - rr, cx + rr, hy + rr], fill=c)
    d.ellipse([cx - hr, hy - hr, cx + hr, hy + hr], fill=None,
              outline=BODY_DARK, width=2)
    # 头部高光
    hl_r = hr * 0.32
    d.ellipse([cx - hr * 0.35 - hl_r, hy - hr * 0.4 - hl_r,
               cx - hr * 0.35 + hl_r, hy - hr * 0.4 + hl_r],
              fill=(255, 255, 255, 80))

    # ---- 耳朵 ----
    er = 11 * s
    for sign in (-1, 1):
        ex = cx + sign * 36 * s
        ey = hy - hr * 0.85
        d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=BODY)
        d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=None,
                  outline=BODY_DARK, width=2)
        # 内耳
        d.ellipse([ex - er * 0.55, ey - er * 0.55, ex + er * 0.55, ey + er * 0.55],
                  fill=EAR_INNER)

    # ---- 手臂 ----
    arm_w = 16 * s
    for sign in (-1, 1):
        ax0 = cx + sign * (bw / 2 - 4 * s)
        ay0 = by0 + 20 * s
        ax1 = ax0 + sign * (30 * s)
        ay1 = ay0 + 55 * s
        d.line([(ax0, ay0), (ax1, ay1)], fill=BODY, width=int(arm_w))
        # 手
        hr2 = 9 * s
        d.ellipse([ax1 - hr2, ay1 - hr2, ax1 + hr2, ay1 + hr2], fill=BODY_LIGHT)

    # ---- 腿 ----
    leg_w = 18 * s
    for sign in (-1, 1):
        lx = cx + sign * 18 * s
        ly0 = by0 + bh - 4 * s
        ly1 = ly0 + 32 * s
        d.line([(lx, ly0), (lx, ly1)], fill=BODY_DARK, width=int(leg_w))
        # 鞋子
        sr = 11 * s
        d.ellipse([lx - sr, ly1 - sr * 0.3, lx + sr, ly1 + sr * 0.9],
                  fill=(80, 60, 40))

    # ---- 腮红 ----
    blush_r = 14 * s
    for sign in (-1, 1):
        bx = cx + sign * 26 * s
        by = hy + 10 * s
        for i in range(3):
            br = max(1.0, blush_r - i * 3)
            a = 90 - i * 20
            d.ellipse([bx - br, by - br, bx + br, by + br],
                      fill=(255, 150, 150, a))

    # ---- 眼睛 (大眼 + 高光) ----
    eye_r = 11 * s
    pupil_r = 7 * s
    for sign in (-1, 1):
        ex = cx + sign * 18 * s
        ey = hy - 2 * s
        # 眼白
        d.ellipse([ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r], fill=(255, 255, 255))
        # 瞳孔
        d.ellipse([ex - pupil_r, ey - pupil_r, ex + pupil_r, ey + pupil_r], fill=EYE)
        # 大高光
        hl = 3.5 * s
        d.ellipse([ex - pupil_r * 0.5 - hl, ey - pupil_r * 0.6 - hl,
                   ex - pupil_r * 0.5 + hl, ey - pupil_r * 0.6 + hl],
                  fill=EYE_HL)
        # 小高光
        hl2 = 1.8 * s
        d.ellipse([ex + pupil_r * 0.3 - hl2, ey + pupil_r * 0.2 - hl2,
                   ex + pupil_r * 0.3 + hl2, ey + pupil_r * 0.2 + hl2],
                  fill=EYE_HL)

    # ---- 嘴巴 (微笑弧线) ----
    mw = 18 * s
    my = hy + 18 * s
    d.arc([cx - mw, my - 10 * s, cx + mw, my + 14 * s],
          start=15, end=165, fill=MOUTH, width=max(2, int(3 * s)))


def make_icon(size, with_bg=True, with_weather=True):
    """生成单个图标"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # 圆角遮罩 (Android adaptive 风格的全圆角)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size, size], radius=int(size * 0.22), fill=255)

    if with_bg:
        bg = gradient_bg((size, size))
        img.paste(bg, (0, 0))

        if with_weather:
            # 右上角太阳
            sun_r = size * 0.11
            draw_sun(img, size * 0.80, size * 0.20, sun_r)
            # 左上角小云
            draw_cloud(img, size * 0.25, size * 0.18, size / 256)

    # 小人 (居中偏下)
    cx = size * 0.5
    cy = size * 0.46
    scale = size / 256 * 0.95
    draw_pet(img, cx, cy, scale)

    # 应用圆角遮罩
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def make_foreground(size):
    """adaptive icon 的前景层 (透明背景, 只有小人)"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = size * 0.5
    cy = size * 0.46
    scale = size / 256 * 0.78  # 前景要留 padding 给 adaptive 裁剪
    draw_pet(img, cx, cy, scale)
    # 加个小太阳点缀
    draw_sun(img, size * 0.78, size * 0.24, size * 0.085)
    draw_cloud(img, size * 0.28, size * 0.22, size / 256 * 0.85)
    return img


def make_background(size):
    """adaptive icon 的背景层 (纯渐变)"""
    return gradient_bg((size, size))


def main():
    project = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res_dir = os.path.join(project, "android", "res")

    # 1. Godot 项目图标 (256, 也用于 splash)
    icon = make_icon(256)
    icon_path = os.path.join(project, "icon.png")
    icon.save(icon_path)
    print(f"✅ Godot icon.png (256x256): {icon_path}")

    # 2. Android 各分辨率 mipmap
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in sizes.items():
        d = os.path.join(res_dir, folder)
        os.makedirs(d, exist_ok=True)
        ic = make_icon(sz)
        ic.save(os.path.join(d, "icon.png"))
        print(f"✅ {folder}/icon.png ({sz}x{sz})")

    # 2b. 无密度限定的 mipmap/ (覆盖 godot-lib.aar 自带的默认图标)
    nodpi_dir = os.path.join(res_dir, "mipmap")
    os.makedirs(nodpi_dir, exist_ok=True)
    make_icon(192).save(os.path.join(nodpi_dir, "icon.png"))
    make_foreground(192).save(os.path.join(nodpi_dir, "icon_foreground.png"))
    make_background(192).save(os.path.join(nodpi_dir, "icon_background.png"))
    # 单色版 (themed icon 用): 从前景生成剪影
    fg = make_foreground(192).convert("L")
    fg.save(os.path.join(nodpi_dir, "icon_monochrome.png"))
    print(f"✅ mipmap/icon.png (192x192, 覆盖默认)")

    # 3. adaptive icon (Android 8.0+) 前景 + 背景
    anydpi = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    # 前景 432x432 (Godot 模板要求) 各密度
    for folder, sz in {
        "mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432
    }.items():
        d = os.path.join(res_dir, folder)
        os.makedirs(d, exist_ok=True)
        make_foreground(sz).save(os.path.join(d, "icon_foreground.png"))
        make_background(sz).save(os.path.join(d, "icon_background.png"))
    print("✅ adaptive icon 前景/背景 (各密度)")

    # adaptive icon XML
    with open(os.path.join(anydpi, "icon.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@mipmap/icon_background"/>\n'
            '    <foreground android:drawable="@mipmap/icon_foreground"/>\n'
            '</adaptive-icon>\n')
    print("✅ mipmap-anydpi-v26/icon.xml")

    print("\n🎉 所有图标已生成!")


if __name__ == "__main__":
    main()
