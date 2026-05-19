# 播放器管理

## 概述

播放器命令用于管理频道播放器配置，包括水印设置、暖场图片和基础访问量等。

## 获取播放器配置

```bash
# 获取频道播放器配置
npx polyv-live-cli@latest player config get -c 3151318

# JSON输出
npx polyv-live-cli@latest player config get -c 3151318 -o json
```

### 输出示例

```
┌─────────────────────┬──────────────────────────────┐
│ Setting             │ Value                        │
├─────────────────────┼──────────────────────────────┤
│ Watermark Enabled   │ Y                            │
│ Watermark URL       │ http://example.com/logo.png  │
│ Watermark Position  │ br (Bottom-right)            │
│ Watermark Opacity   │ 0.8                          │
│ Warmup Enabled      │ Y                            │
│ Warmup Image URL    │ http://example.com/warmup.jpg│
│ Base Page Views     │ 1000                         │
└─────────────────────┴──────────────────────────────┘
```

## 更新播放器配置

### 水印设置

```bash
# 启用水印
npx polyv-live-cli@latest player config update -c 3151318 --watermark-enabled Y

# 设置水印图片
npx polyv-live-cli@latest player config update -c 3151318 --watermark-url "http://example.com/logo.png"

# 设置水印位置
npx polyv-live-cli@latest player config update -c 3151318 --watermark-position br

# 设置水印透明度
npx polyv-live-cli@latest player config update -c 3151318 --watermark-opacity 0.8

# 完整水印配置
npx polyv-live-cli@latest player config update -c 3151318 \
  --watermark-enabled Y \
  --watermark-url "http://example.com/logo.png" \
  --watermark-position br \
  --watermark-opacity 0.8
```

### 水印位置说明

| 值 | 位置 |
|----|------|
| `tl` | 左上角 (Top-left) |
| `tr` | 右上角 (Top-right) |
| `bl` | 左下角 (Bottom-left) |
| `br` | 右下角 (Bottom-right) |

### 水印透明度

- 范围：0 - 1
- 0 = 完全透明
- 1 = 完全不透明
- 推荐值：0.7 - 0.9

### 暖场设置

```bash
# 启用暖场图片
npx polyv-live-cli@latest player config update -c 3151318 --warmup-enabled Y

# 设置暖场图片
npx polyv-live-cli@latest player config update -c 3151318 --warmup-image-url "http://example.com/warmup.jpg"

# 完整暖场配置
npx polyv-live-cli@latest player config update -c 3151318 \
  --warmup-enabled Y \
  --warmup-image-url "http://example.com/warmup.jpg"
```

### 基础访问量

```bash
# 设置基础访问量
npx polyv-live-cli@latest player config update -c 3151318 --base-pv 1000
```

> **说明**: 基础访问量会在实际访问量基础上叠加显示，用于初始化显示数据。

## 更新选项汇总

| 选项 | 说明 | 格式 |
|------|------|------|
| `--watermark-enabled` | 启用/禁用水印 | Y / N |
| `--watermark-url` | 水印图片URL | 完整URL |
| `--watermark-position` | 水印位置 | tl / tr / bl / br |
| `--watermark-opacity` | 水印透明度 | 0 - 1 |
| `--warmup-enabled` | 启用/禁用暖场 | Y / N |
| `--warmup-image-url` | 暖场图片URL | 完整URL |
| `--base-pv` | 基础访问量 | 数字 |
| `-o, --output` | 输出格式 | table / json |

## 常用工作流程

### 配置品牌水印

```bash
# 1. 获取当前配置
npx polyv-live-cli@latest player config get -c 3151318

# 2. 配置品牌水印
npx polyv-live-cli@latest player config update -c 3151318 \
  --watermark-enabled Y \
  --watermark-url "https://cdn.example.com/brand-logo.png" \
  --watermark-position br \
  --watermark-opacity 0.7

# 3. 验证配置
npx polyv-live-cli@latest player config get -c 3151318 -o json
```

### 配置直播暖场

```bash
# 1. 准备暖场图片（建议16:9比例）
# 2. 上传到CDN获取URL

# 3. 配置暖场图片
npx polyv-live-cli@latest player config update -c 3151318 \
  --warmup-enabled Y \
  --warmup-image-url "https://cdn.example.com/warmup.jpg"

# 4. 直播开始后禁用暖场（可选）
npx polyv-live-cli@latest player config update -c 3151318 --warmup-enabled N
```

### 批量配置多个频道

```bash
# 为多个频道应用相同配置
for channel in 3151318 3151319 3151320; do
  npx polyv-live-cli@latest player config update -c $channel \
    --watermark-enabled Y \
    --watermark-url "https://cdn.example.com/logo.png" \
    --watermark-position br \
    --watermark-opacity 0.8
done
```

### 导出和导入配置

```bash
# 导出配置
npx polyv-live-cli@latest player config get -c 3151318 -o json > player-config.json

# 查看配置
cat player-config.json

# 可以用于文档记录或其他频道的参考
```

## Y/N 值说明

以下选项使用 Y/N 格式：

| 值 | 说明 |
|----|------|
| `Y` | 是/启用 |
| `N` | 否/禁用 |

## 输出格式

### 表格格式（默认）

```
┌─────────────────────┬──────────────────────────────┐
│ Setting             │ Value                        │
├─────────────────────┼──────────────────────────────┤
│ Watermark Enabled   │ Y                            │
│ Watermark URL       │ http://example.com/logo.png  │
│ ...                 │ ...                          │
└─────────────────────┴──────────────────────────────┘
```

### JSON格式

```json
{
  "channelId": "3151318",
  "watermark": {
    "enabled": "Y",
    "url": "http://example.com/logo.png",
    "position": "br",
    "opacity": 0.8
  },
  "warmup": {
    "enabled": "Y",
    "imageUrl": "http://example.com/warmup.jpg"
  },
  "basePv": 1000
}
```

## 故障排除

### "水印不显示"

- 确认 `--watermark-enabled` 设置为 Y
- 检查图片URL是否可访问
- 确保图片格式为 PNG、JPG 或 GIF
- 检查透明度设置（0.5以上更明显）

### "暖场图片不显示"

- 确认 `--warmup-enabled` 设置为 Y
- 检查图片URL是否有效
- 建议使用 CDN 托管图片
- 图片建议尺寸：1920x1080（16:9）

### "配置更新失败"

- 确认频道ID正确
- 检查URL格式是否正确（需包含 http:// 或 https://）
- 确保有频道管理权限

### "参数值无效"

- `--watermark-position` 只接受 tl/tr/bl/br
- `--watermark-opacity` 范围为 0-1
- `--watermark-enabled` 和 `--warmup-enabled` 只接受 Y 或 N
