# 网速显示 (NetSpeedMonitor)

一款 macOS 菜单栏网速监控应用，实时显示网络速度和应用流量统计。

## 功能特性

- ✅ 实时显示下载/上传速度
- ✅ 毛玻璃效果菜单面板
- ✅ 应用下载速度排行
- ✅ 流量使用累计统计
- ✅ 开机自启动选项
- ✅ 显示/隐藏上传下载速度
- ✅ 重置流量统计
- ✅ macOS 风格应用图标

## 截图

![Screenshot](screenshot.png)

## 系统要求

- macOS 10.13 或更高版本
- Apple Silicon 或 Intel 处理器

## 安装

### 方式一：下载发布版本

1. 前往 [Releases](../../releases) 页面
2. 下载最新版本的 `NetSpeedMonitor.dmg`
3. 打开 DMG 文件，将应用拖入 Applications 文件夹
4. 首次运行可能需要右键点击 → 打开

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/yourusername/NetSpeedMonitor.git
cd NetSpeedMonitor

# 构建
swift build -c release

# 运行
.build/release/NetSpeedMonitor
```

## 使用方法

1. 点击菜单栏图标查看详细网速信息
2. 在菜单中可以：
   - 显示/隐藏上传速度
   - 显示/隐藏下载速度
   - 设置开机自启动
   - 重置流量统计
   - 退出应用

## 技术栈

- Swift 5.5
- AppKit
- Network Framework

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
