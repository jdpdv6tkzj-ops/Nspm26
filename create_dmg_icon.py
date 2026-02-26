from PIL import Image, ImageDraw
import os

# 直接使用AppIcon.iconset的图标，缩小内容并调整遮罩
def create_small_icon(input_path, output_path, size):
    # 打开原始图标
    icon = Image.open(input_path).convert('RGBA')
    
    # 创建一个新的图像，留出边距
    padding = int(size * 0.12)  # 12%的边距（之前是18%，现在调小）
    content_size = size - (padding * 2)
    
    # 调整图标尺寸（缩小）
    icon_resized = icon.resize((content_size, content_size), Image.Resampling.LANCZOS)
    
    # 创建圆角遮罩（只覆盖内容区域）
    mask = Image.new('L', (content_size, content_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    
    # 圆角半径（相对于内容区域）
    corner_radius = int(content_size * 0.22)
    
    # 绘制圆角矩形遮罩
    mask_draw.rounded_rectangle([0, 0, content_size, content_size], radius=corner_radius, fill=255)
    
    # 应用圆角遮罩到缩小的图标
    icon_resized.putalpha(mask)
    
    # 创建最终画布（透明背景）
    final_icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # 将带遮罩的图标粘贴到中心
    final_icon.paste(icon_resized, (padding, padding))
    
    # 保存
    final_icon.save(output_path)
    return final_icon

# 创建DMGIcon.iconset目录
os.makedirs('DMGIcon.iconset', exist_ok=True)

# 使用128x128作为基础图标
source_size = 128
source_file = f'AppIcon.iconset/icon_{source_size}x{source_size}.png'

if os.path.exists(source_file):
    # DMG卷图标通常只需要几个关键尺寸
    target_sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    for size in target_sizes:
        output_file = f'DMGIcon.iconset/icon_{size}x{size}.png'
        print(f"Creating icon {size}x{size}...")
        create_small_icon(source_file, output_file, size)
        
        # 创建@2x版本
        if size <= 512:
            output_file_2x = f'DMGIcon.iconset/icon_{size}x{size}@2x.png'
            create_small_icon(source_file, output_file_2x, size * 2)

print("DMG icons created successfully!")
print("Now run: iconutil -c icns DMGIcon.iconset -o DMGIcon.icns")
