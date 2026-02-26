#!/bin/bash

# 设置变量
APP_NAME="Nspm26"
APP_PATH="release/$APP_NAME.app"
DMG_PATH="release/$APP_NAME-v1.0.0.dmg"
BACKGROUND_PATH="release/background.png"
ICON_PATH="DMGIcon.icns"

# 检查应用是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Application not found at $APP_PATH"
    echo "Please build the application first"
    exit 1
fi

# 检查背景图像是否存在
if [ ! -f "$BACKGROUND_PATH" ]; then
    echo "Error: Background image not found at $BACKGROUND_PATH"
    exit 1
fi

# 检查图标文件是否存在
if [ ! -f "$ICON_PATH" ]; then
    echo "Error: Icon file not found at $ICON_PATH"
    exit 1
fi

# 清理旧的DMG
if [ -f "$DMG_PATH" ]; then
    echo "Removing old DMG..."
    rm "$DMG_PATH"
fi

# 使用create-dmg创建DMG
# 窗口大小与背景图像一致 560x380
# 图标位置：左侧应用图标在 (140, 215)，右侧Applications在 (420, 215) - 提高20px
echo "Creating DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --volicon "$ICON_PATH" \
  --background "$BACKGROUND_PATH" \
  --window-size 560 380 \
  --icon-size 80 \
  --icon "$APP_NAME.app" 140 215 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 420 215 \
  "$DMG_PATH" \
  "$APP_PATH"

echo "DMG created successfully at $DMG_PATH"
