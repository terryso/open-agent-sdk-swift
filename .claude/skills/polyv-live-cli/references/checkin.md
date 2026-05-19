# 签到管理

## 概述

签到命令用于在直播过程中发起签到互动，查询签到记录和统计结果。

## 发起签到

```bash
# 立即发起签到
npx polyv-live-cli@latest checkin start -c 3151318

# 设置签到时长30秒
npx polyv-live-cli@latest checkin start -c 3151318 --limit-time 30

# 定时签到（13位时间戳）
npx polyv-live-cli@latest checkin start -c 3151318 --limit-time 60 --delay-time 1700734800000

# 自定义签到提示语
npx polyv-live-cli@latest checkin start -c 3151318 --message "请各位学员签到"

# 强制签到模式
npx polyv-live-cli@latest checkin start -c 3151318 --force
```

### 签到选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--limit-time` | 签到时长（秒） | 0-86400，0表示立即 |
| `--delay-time` | 定时签到时间 | 13位时间戳 |
| `--message` | 签到提示语 | 文本 |
| `--force` | 强制签到模式 | 标志（无需值） |
| `-o, --output` | 输出格式 | table（默认）/ json |

### JSON输出

```bash
npx polyv-live-cli@latest checkin start -c 3151318 -o json
```

## 查询签到记录

查询已签到的用户列表。

```bash
# 查询所有签到记录
npx polyv-live-cli@latest checkin list -c 3151318

# 分页查询
npx polyv-live-cli@latest checkin list -c 3151318 --page 1 --size 20

# 按日期筛选
npx polyv-live-cli@latest checkin list -c 3151318 --date 2024-01-15

# 按场次筛选
npx polyv-live-cli@latest checkin list -c 3151318 --session-id fwly13xczv

# JSON输出
npx polyv-live-cli@latest checkin list -c 3151318 -o json
```

### 查询选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--page` | 页码 | 数字，默认1 |
| `--size` | 每页数量 | 数字，默认10 |
| `--date` | 筛选日期 | yyyy-MM-dd |
| `--session-id` | 场次ID | - |
| `-o, --output` | 输出格式 | table（默认）/ json |

## 查询签到详情

获取特定签到的详细结果，包括已签到和未签到的用户。

```bash
# 查询签到详情
npx polyv-live-cli@latest checkin result -c 3151318 --checkin-id db14ef80-81b8-11eb-b114-e7477b

# JSON输出
npx polyv-live-cli@latest checkin result -c 3151318 --checkin-id db14ef80-81b8-11eb-b114-e7477b -o json
```

### 详情选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--checkin-id` | 签到ID（必填） | - |
| `-o, --output` | 输出格式 | table（默认）/ json |

## 查询签到发起记录

按时间范围查询签到发起记录。

```bash
# 查询最近7天的签到记录（默认）
npx polyv-live-cli@latest checkin sessions -c 3151318

# 指定日期范围
npx polyv-live-cli@latest checkin sessions -c 3151318 --start-date 2024-01-01 --end-date 2024-01-31

# JSON输出
npx polyv-live-cli@latest checkin sessions -c 3151318 --start-date 2024-01-01 --end-date 2024-01-31 -o json
```

### 场次选项

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--start-date` | 开始日期 | yyyy-MM-dd，默认7天前 |
| `--end-date` | 结束日期 | yyyy-MM-dd，默认今天 |
| `-o, --output` | 输出格式 | table（默认）/ json |

> **注意**: 日期范围不能超过30天。

## 常用工作流程

### 课堂签到流程

```bash
# 1. 开始直播后发起签到
npx polyv-live-cli@latest checkin start -c 3151318 --limit-time 60 --message "同学们请签到"

# 2. 签到结束后查看结果
npx polyv-live-cli@latest checkin result -c 3151318 --checkin-id <签到ID>

# 3. 导出签到数据
npx polyv-live-cli@latest checkin result -c 3151318 --checkin-id <签到ID> -o json > checkin-result.json
```

### 课后统计

```bash
# 查询某天的所有签到记录
npx polyv-live-cli@latest checkin list -c 3151318 --date 2024-01-15 -o json

# 查询某月的签到发起记录
npx polyv-live-cli@latest checkin sessions -c 3151318 --start-date 2024-01-01 --end-date 2024-01-31
```

### 定时签到

```bash
# 计算定时签到时间戳（例如：2024-01-15 10:00:00）
# macOS/Linux
date -j -f "%Y-%m-%d %H:%M:%S" "2024-01-15 10:00:00" +%s000

# 发起定时签到
npx polyv-live-cli@latest checkin start -c 3151318 --limit-time 120 --delay-time 1705287600000
```

## 输出格式

### 表格格式（默认）

```
┌──────────────────────────────┬──────────┬─────────────────┐
│ Checkin ID                   │ Status   │ Checked Count   │
├──────────────────────────────┼──────────┼─────────────────┤
│ db14ef80-81b8-11eb-b114...   │ Active   │ 45              │
└──────────────────────────────┴──────────┴─────────────────┘
```

### JSON格式

```json
{
  "checkinId": "db14ef80-81b8-11eb-b114-e7477b",
  "channelId": "3151318",
  "status": "active",
  "checkedCount": 45,
  "uncheckedCount": 10,
  "limitTime": 60,
  "message": "请签到"
}
```

## 故障排除

### "签到发起失败"

- 确认频道正在直播中
- 检查是否有正在进行的签到（需先结束或等待超时）
- 使用 `--force` 参数强制发起新签到

### "无签到记录"

- 确认日期范围正确
- 检查频道ID是否正确
- 确认该时间段内有直播场次

### "日期范围超出限制"

- 日期范围不能超过30天
- 缩小查询日期范围后重试
