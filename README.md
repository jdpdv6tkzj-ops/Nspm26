# Nspm26 - 网速监控工具

一款 macOS 菜单栏网速监控工具，实时显示网络上传/下载速度，支持进程级流量监控。

## 功能特性

- **实时网速显示** - 在菜单栏显示上传/下载速度
- **进程级流量监控** - 显示各应用的实时下载速度
- **流量使用排行** - 统计各应用的累计流量使用
- **智能应用识别** - 自动识别 Electron 应用（如 Trae）及其 Helper 进程
- **开机自启动** - 支持设置开机自动启动

## 系统要求

- macOS 10.13 或更高版本

## 构建

```bash
cd NetSpeedMonitor
swift build -c release
```

## 打包

```bash
# 创建 app 包
mkdir -p dist/Nspm26.app/Contents/MacOS
mkdir -p dist/Nspm26.app/Contents/Resources
cp .build/release/NetSpeedMonitor dist/Nspm26.app/Contents/MacOS/
chmod +x dist/Nspm26.app/Contents/MacOS/NetSpeedMonitor
```

## 使用

点击菜单栏图标打开面板，查看：
- 当前上传/下载速度
- 应用下载速度排行
- 流量使用排行

## 许可证

MIT License
