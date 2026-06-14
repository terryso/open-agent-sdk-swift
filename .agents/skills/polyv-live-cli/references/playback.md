# 回放管理

## 概述

回放是直播录制的视频文件。可以查看、删除或合并回放视频。

## 回放列表

### 基本列表

```bash
npx polyv-live-cli@latest playback list -c 3151318

# 输出：
# 视频ID | 标题 | 时长 | 大小 | 创建时间
# vid001 | 第一场直播 | 01:30:45 | 1.2GB | 2024-06-15
# vid002 | 第二场直播 | 00:45:22 | 0.8GB | 2024-06-16
```

### JSON输出

```bash
npx polyv-live-cli@latest playback list -c 3151318 -o json
```

## 获取回放详情

```bash
# 表格格式
npx polyv-live-cli@latest playback get -c 3151318 --videoId vid001

# JSON格式
npx polyv-live-cli@latest playback get -c 3151318 --videoId vid001 -o json
```

### 回放信息包括

- 视频ID和标题
- 时长
- 文件大小
- 创建时间
- 播放地址
- 缩略图地址
- 状态

## 删除回放

```bash
# 带确认提示
npx polyv-live-cli@latest playback delete -c 3151318 --videoId vid001

# 强制删除
npx polyv-live-cli@latest playback delete -c 3151318 --videoId vid001 -f
```

## 合并回放

将多个回放视频合并为一个视频。

### 基本合并

```bash
npx polyv-live-cli@latest playback merge \
  -c 3151318 \
  --videoIds vid001 vid002 vid003

# 输出：
# ✅ 合并任务已开始
# 新视频ID: vid999
# 状态: 处理中
```

### 指定标题

```bash
npx polyv-live-cli@latest playback merge \
  -c 3151318 \
  --videoIds vid001 vid002 \
  --title "完整研讨会合集"
```

### JSON输出

```bash
npx polyv-live-cli@latest playback merge \
  -c 3151318 \
  --videoIds vid001 vid002 \
  -o json
```

## 常用工作流程

### 清理旧录像

```bash
# 列出旧录像
npx polyv-live-cli@latest playback list -c 3151318 -o json | \
  jq '.data[] | select(.createdAt < "2024-01-01")'

# 删除旧录像
for vid in $(npx polyv-live-cli@latest playback list -c 3151318 -o json | \
  jq -r '.data[] | select(.createdAt < "2024-01-01") | .videoId'); do
  npx polyv-live-cli@latest playback delete -c 3151318 --videoId "$vid" -f
done
```

### 合并多场直播录像

```bash
# 合并多天活动的所有录像
npx polyv-live-cli@latest playback merge \
  -c 3151318 \
  --videoIds vid001 vid002 vid003 vid004 \
  --title "完整会议录像"
```

### 导出播放地址

```bash
# 获取所有回放的播放地址
npx polyv-live-cli@latest playback list -c 3151318 -o json | \
  jq -r '.data[] | "\(.title): \(.playbackUrl)"'
```

## 回放状态

| 状态 | 说明 |
|------|------|
| `ready` | 可以播放 |
| `processing` | 正在处理 |
| `error` | 处理失败 |
| `merging` | 正在合并 |

## 故障排除

### "Playback not found"（回放不存在）

- 确认视频ID是否正确
- 检查回放是否属于该频道

### "Merge failed"（合并失败）

- 确保所有视频ID有效
- 检查视频是否都处于 `ready` 状态
- 尝试减少合并的视频数量

### "Playback still processing"（回放仍在处理中）

- 等待处理完成
- 检查状态：`npx polyv-live-cli@latest playback get -c <频道ID> --videoId <视频ID>`
- 处理通常每1小时内容需要1-5分钟
