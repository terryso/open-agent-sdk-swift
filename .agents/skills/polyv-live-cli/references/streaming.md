# 推流操作

## 概述

推流命令用于管理直播推流操作，包括获取推流凭证、开始/结束直播、监控直播质量等。

## 获取推流凭证

### 基本使用

```bash
# 获取RTMP地址和推流密钥
npx polyv-live-cli@latest stream get-key -c 3151318

# 输出：
# RTMP地址: rtmp://push.polyv.net/live/
# 推流密钥: 3151318-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### JSON输出（用于脚本）

```bash
npx polyv-live-cli@latest stream get-key -c 3151318 -o json

# {
#   "rtmpUrl": "rtmp://push.polyv.net/live/",
#   "streamKey": "3151318-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "fullRtmpUrl": "rtmp://push.polyv.net/live/3151318-xxxx-xxxx..."
# }
```

## 开始和结束直播

### 开始直播

```bash
# 开始直播推流
npx polyv-live-cli@latest stream start -c 3151318

# 输出：
# ✅ 直播已开始
# 频道ID: 3151318
# 状态: 直播中
```

### 结束直播

```bash
# 结束直播
npx polyv-live-cli@latest stream stop -c 3151318

# 输出：
# ✅ 直播已结束
# 频道ID: 3151318
# 状态: 已结束
```

## 直播状态

### 单次状态查询

```bash
npx polyv-live-cli@latest stream status -c 3151318

# 输出包含：
# 状态: 直播中
# 时长: 00:45:32
# 帧率: 30
# 码率: 2500 kbps
# 观看人数: 127
```

### 持续监控

```bash
# 监控模式（每5秒刷新）
npx polyv-live-cli@latest stream status -c 3151318 -w

# 按 Ctrl+C 停止
```

### JSON输出

```bash
npx polyv-live-cli@latest stream status -c 3151318 -o json

# {
#   "status": "live",
#   "duration": 2732,
#   "fps": 30,
#   "bandwidth": 2500,
#   "viewerCount": 127
# }
```

## 推送视频文件

### 基本推送

```bash
# 推送本地视频文件到频道
# 需要安装 FFmpeg
npx polyv-live-cli@latest stream push -c 3151318 -f /path/to/video.mp4
```

### 带质量验证

```bash
# 推送并实时验证质量
npx polyv-live-cli@latest stream push \
  -c 3151318 \
  -f video.mp4 \
  --verify \
  --verification-interval 5 \
  --quality-threshold 20
```

### 显示观众链接

```bash
# 推送时显示观众观看链接
npx polyv-live-cli@latest stream push -c 3151318 -f video.mp4 --show-viewer-links
```

## 直播质量验证

### 基本验证

```bash
# 验证直播质量（60秒）
npx polyv-live-cli@latest stream verify -c 3151318

# 输出包含：
# ✅ 直播质量报告
# 验证时长: 60秒
# 平均帧率: 29.5
# 平均码率: 2450 kbps
# 质量评分: 95%
```

### 扩展验证

```bash
# 2分钟验证，每5秒检测一次
npx polyv-live-cli@latest stream verify -c 3151318 -d 120 -i 5
```

### 保存报告

```bash
# 保存验证报告到文件
npx polyv-live-cli@latest stream verify -c 3151318 -s report.json -o json
```

### 验证选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-d, --duration` | 验证时长（秒） | 60 |
| `-i, --interval` | 检测间隔（秒） | 10 |
| `-t, --quality-threshold` | 帧率警告阈值 | 15 |
| `--show-viewer-links` | 显示观众链接 | false |
| `-s, --save-report` | 保存报告到文件 | - |
| `-o, --output` | 输出格式 | table |

## 实时监控面板

### 基本监控

```bash
# 实时监控面板
npx polyv-live-cli@latest stream monitor -c 3151318

# 面板显示：
# ┌─────────────────────────────────────┐
# │ 📺 直播监控面板                      │
# ├─────────────────────────────────────┤
# │ 状态: 🔴 直播中                      │
# │ 时长: 00:32:15                      │
# │ 帧率: 30 | 码率: 2500 kbps          │
# │ 观看人数: 127                        │
# └─────────────────────────────────────┘
```

### 启用告警

```bash
# 启用质量告警
npx polyv-live-cli@latest stream monitor -c 3151318 -r 3 --alerts

# 以下情况会告警：
# - 帧率低于阈值
# - 码率波动较大
# - 直播不稳定
```

### 监控选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-r, --refresh` | 刷新间隔（秒） | 5 |
| `--alerts` | 启用质量告警 | false |
| `-o, --output` | 输出格式 | table |

## 配合 OBS Studio 使用

### 步骤1：获取推流凭证

```bash
npx polyv-live-cli@latest stream get-key -c 3151318 -o json
```

### 步骤2：配置 OBS

1. 打开 OBS Studio
2. 进入 **设置** → **推流**
3. 将 **服务** 设置为 "自定义"
4. 将 **RTMP地址** 复制到 **服务器** 字段
5. 将 **推流密钥** 复制到 **串流密钥** 字段
6. 点击 **确定**

### 步骤3：开始直播

```bash
# 在保利威平台开始直播
npx polyv-live-cli@latest stream start -c 3151318

# 在 OBS 中点击"开始推流"

# 监控直播状态
npx polyv-live-cli@latest stream status -c 3151318 -w
```

### 步骤4：结束直播

```bash
# 先在 OBS 中停止推流

# 然后在保利威平台结束直播
npx polyv-live-cli@latest stream stop -c 3151318
```

## 配合 FFmpeg 使用

### 直接使用 FFmpeg 推流

```bash
# 先获取推流凭证
npx polyv-live-cli@latest stream get-key -c 3151318 -o json

# 使用 FFmpeg 推流
ffmpeg -re -i video.mp4 \
  -c:v libx264 -c:a aac \
  -f flv "rtmp://push.polyv.net/live/推流密钥"
```

### 或使用内置推送命令

```bash
# 更简单 - CLI自动处理
npx polyv-live-cli@latest stream push -c 3151318 -f video.mp4 --verify
```

## 直播状态说明

| 状态 | 说明 |
|------|------|
| `live` | 正在直播 |
| `waiting` | 频道已创建，未开始 |
| `stopped` | 直播已结束 |
| `error` | 直播出错 |

## 故障排除

### "FFmpeg not found"（未找到FFmpeg）

安装 FFmpeg：
```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

# Windows
# 从 https://ffmpeg.org/download.html 下载
```

### "Channel must be in live state"（频道必须处于直播状态）

- 先开始直播：`npx polyv-live-cli@latest stream start -c <频道ID>`
- 确认频道已激活：`npx polyv-live-cli@latest channel get -c <频道ID>`

### 帧率过低警告

- 检查网络带宽
- 在编码器中降低视频质量
- 使用有线网络代替WiFi
