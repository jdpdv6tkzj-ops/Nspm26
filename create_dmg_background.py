from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

# 创建背景图像 - 使用更大的尺寸，最后缩放以获得更好的抗锯齿效果
scale_factor = 2
width, height = 560 * scale_factor, 380 * scale_factor

# 创建基础黑色背景
img = Image.new('RGBA', (width, height), (15, 15, 18, 255))
draw = ImageDraw.Draw(img)

# 绘制绿色点阵装饰（更淡）
def draw_dot_pattern(draw, start_x, start_y, pattern_width, pattern_height, dot_size=3, spacing=22):
    for x in range(start_x, start_x + pattern_width, spacing):
        for y in range(start_y, start_y + pattern_height, spacing):
            if (x + y) % 19 < 3:
                continue
            opacity = 5 + ((x + y) % 8)
            draw.ellipse([x, y, x + dot_size, y + dot_size], 
                        fill=(0, 150, 0, opacity))

# 四个角的点阵
draw_dot_pattern(draw, 40, 120, 320, 160)
draw_dot_pattern(draw, 760, 110, 280, 140)
draw_dot_pattern(draw, 60, 600, 220, 120)
draw_dot_pattern(draw, 820, 580, 240, 140)

# 对背景进行轻微模糊处理
img = img.filter(ImageFilter.GaussianBlur(radius=1.0))
draw = ImageDraw.Draw(img)

# 计算卡片位置和尺寸（在缩放后的坐标系中）
# 目标：左右边距40px，底部边距70px
margin = 40 * scale_factor
bottom_margin = 70 * scale_factor  # 改为70px
card_width = width - (margin * 2)
card_height = 190 * scale_factor
card_x = margin
card_y = height - bottom_margin - card_height
card_radius = 16 * scale_factor

# 绘制圆角矩形 - 使用抗锯齿方法
def draw_rounded_rect_aa(draw, coords, radius, fill):
    x1, y1, x2, y2 = coords
    r = radius
    
    # 绘制主体矩形
    draw.rectangle([x1 + r, y1, x2 - r, y2], fill=fill)
    draw.rectangle([x1, y1 + r, x2, y2 - r], fill=fill)
    
    # 绘制四个圆角 - 使用 pieslice 绘制圆角
    draw.pieslice([x1, y1, x1 + r * 2, y1 + r * 2], 180, 270, fill=fill)
    draw.pieslice([x2 - r * 2, y1, x2, y1 + r * 2], 270, 360, fill=fill)
    draw.pieslice([x1, y2 - r * 2, x1 + r * 2, y2], 90, 180, fill=fill)
    draw.pieslice([x2 - r * 2, y2 - r * 2, x2, y2], 0, 90, fill=fill)

# 绘制卡片背景 - 使用更浅的颜色
card_color = (160, 160, 165, 255)
draw_rounded_rect_aa(draw, [card_x, card_y, card_x + card_width, card_y + card_height], 
                  card_radius, card_color)

# 尝试加载中文字体
font_title = None
font_subtitle = None
font_small = None

font_paths = [
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/STHeiti Light.ttc',
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
]

for font_path in font_paths:
    try:
        if os.path.exists(font_path):
            font_title = ImageFont.truetype(font_path, 36 * scale_factor)
            font_subtitle = ImageFont.truetype(font_path, 15 * scale_factor)
            font_small = ImageFont.truetype(font_path, 13 * scale_factor)
            print(f"Loaded font: {font_path}")
            break
    except Exception as e:
        print(f"Failed to load {font_path}: {e}")

if font_title is None:
    font_title = ImageFont.load_default()
    font_subtitle = ImageFont.load_default()
    font_small = ImageFont.load_default()
    print("Using default font")

# 计算标题和副标题的位置（在卡片上方）
# 标题：card_y - 50px，副标题：card_y - 20px
title_y = card_y - (50 * scale_factor)
subtitle_y = card_y - (20 * scale_factor)

# 绘制标题 - 白色大标题
title = "Nspm26"
try:
    draw.text((width // 2, title_y), title, font=font_title, fill=(255, 255, 255), anchor='mm')
except:
    draw.text((width // 2, title_y), title, font=font_title, fill=(255, 255, 255))

# 绘制副标题 - 改为白色
subtitle = "实时网络速度监控工具"
subtitle_color = (255, 255, 255)
try:
    draw.text((width // 2, subtitle_y), subtitle, font=font_subtitle, fill=subtitle_color, anchor='mm')
except:
    draw.text((width // 2, subtitle_y), subtitle, font=font_subtitle, fill=subtitle_color)

# 绘制箭头图标（在卡片中间）
arrow_x = width // 2
arrow_y = card_y + (card_height // 2) - (10 * scale_factor)  # 卡片中心偏上
arrow_color = (100, 100, 100)
try:
    draw.text((arrow_x, arrow_y), "\u00bb", font=font_title, fill=arrow_color, anchor='mm')
except:
    draw.text((arrow_x, arrow_y), ">>", font=font_title, fill=arrow_color)

# 绘制拖拽提示文字（在箭头下方）
drag_text = "拖拽至"
drag_color = (100, 100, 100)
drag_y = card_y + (card_height // 2) + (15 * scale_factor)
try:
    draw.text((width // 2, drag_y), drag_text, font=font_small, fill=drag_color, anchor='mm')
except:
    draw.text((width // 2, drag_y), drag_text, font=font_small, fill=drag_color)

# 缩放回原始尺寸以获得抗锯齿效果
img = img.resize((560, 380), Image.Resampling.LANCZOS)

# 保存背景图像
os.makedirs('release', exist_ok=True)
img.save('release/background.png')
print("Background image created successfully!")
