# 统计分析

## 概述

统计命令提供频道表现、观众行为和直播质量的洞察数据。

## 查看每日观看统计

```bash
npx polyv-live-cli@latest statistics view -c <频道ID> --start-day 2024-01-01 --end-day 2024-01-31

# JSON格式输出
npx polyv-live-cli@latest statistics view -c 3151318 --start-day "2024-01-01" --end-day "2024-01-31" -o json
```

### 选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID | 必填 |
| `--start-day` | 开始日期 | YYYY-MM-DD |
| `--end-day` | 结束日期 | YYYY-MM-DD |
| `-o, --output` | 输出格式 | table（默认）/ json |

## 历史并发数据

查看指定日期范围内的并发数据。

```bash
npx polyv-live-cli@latest statistics concurrency -c <频道ID> --start-date 2024-01-01 --end-date 2024-01-31

# JSON格式输出
npx polyv-live-cli@latest statistics concurrency -c 3151318 --start-date 2024-01-01 --end-date 2024-01-31 -o json
```

### 选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID | 必填 |
| `--start-date` | 开始日期 | YYYY-MM-DD |
| `--end-date` | 结束日期 | YYYY-MM-DD |
| `-o, --output` | 输出格式 | table（默认）/ json |

## 历史最高并发人数

查看指定时间范围内的最高并发观看人数。

```bash
npx polyv-live-cli@latest statistics max-concurrent -c <频道ID> --start-time 1704067200000 --end-time 1735689600000

# JSON格式输出
npx polyv-live-cli@latest statistics max-concurrent -c 3151318 --start-time 1704067200000 --end-time 1735689600000 -o json
```

### 选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID | 必填 |
| `--start-time` | 开始时间戳 | 13位毫秒时间戳 |
| `--end-time` | 结束时间戳 | 13位毫秒时间戳 |
| `-o, --output` | 输出格式 | table（默认）/ json |

**注意：** 时间范围不能超过3个月

## 观众统计

查看观众的设备和地区分布。

### 设备分布

```bash
npx polyv-live-cli@latest statistics audience device -c <频道ID>
```

### 地区分布

```bash
npx polyv-live-cli@latest statistics audience region -c <频道ID>
```

## 导出统计数据

导出频道统计数据到文件。

```bash
npx polyv-live-cli@latest statistics export -c <频道ID> -f csv -o report.csv

# 导出为JSON
npx polyv-live-cli@latest statistics export -c 3151318 -f json -o channel-stats.json
```

### 导出选项

| 选项 | 说明 | 可选值 |
|------|------|--------|
| `-c, --channel-id` | 频道ID | 必填 |
| `-f, --format` | 导出格式 | csv, json |
| `-o, --output` | 输出文件路径 | - |

## 常用工作流程

### 生成周报

```bash
# 查看一周的观看数据
npx polyv-live-cli@latest statistics view \
  -c 3151318 \
  --start-day 2024-06-10 \
  --end-day 2024-06-16

# 导出为CSV
npx polyv-live-cli@latest statistics export \
  -c 3151318 \
  -f csv \
  -o weekly-report.csv
```

### 查看并发峰值

```bash
# 查看一个月内的最高并发
npx polyv-live-cli@latest statistics max-concurrent \
  -c 3151318 \
  --start-time 1704067200000 \
  --end-time 1706745600000
```

### 对比多个频道

```bash
# 导出多个频道的统计
for channel in 3151318 3151319 3151320; do
  npx polyv-live-cli@latest statistics view -c $channel -o json > "channel-$channel.json"
done
```

## 故障排除

### "No data available"（无可用数据）

- 检查日期范围是否有效
- 确认频道已有直播场次
- 确保数据已处理完成（最多需要24小时）

### "Date range too large"（日期范围过大）

- max-concurrent: 时间范围不能超过3个月
- view: 日期范围不能超过60天

### 时间戳转换

```bash
# 将日期转换为13位毫秒时间戳
date -j -f "%Y-%m-%d" "2024-01-01" "+%s"000
# 输出: 1704067200000
```
