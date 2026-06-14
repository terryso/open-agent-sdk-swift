# 抽奖管理

## 概述

抽奖命令用于在直播过程中创建和管理抽奖活动，包括创建、查询、更新、删除抽奖活动，以及查询中奖用户和抽奖记录。

## 创建抽奖

```bash
# 创建无条件抽奖（默认）
npx polyv-live-cli@latest lottery create -c 3151318 --name "幸运抽奖" --type none --amount 3 --prize "神秘礼品"

# 创建邀请抽奖（观众邀请3人参与）
npx polyv-live-cli@latest lottery create -c 3151318 --name "邀请抽奖" --type invite --amount 5 --prize "优惠券" --duration 30 --invite-num 3

# 创建观看时长抽奖（观看10分钟后可参与）
npx polyv-live-cli@latest lottery create -c 3151318 --name "时长抽奖" --type duration --amount 2 --prize "红包" --duration 10

# 创建评论抽奖（发表评论后可参与）
npx polyv-live-cli@latest lottery create -c 3151318 --name "评论抽奖" --type comment --amount 3 --prize "积分" --duration 5

# 创建答题抽奖（回答问题后可参与）
npx polyv-live-cli@latest lottery create -c 3151318 --name "答题抽奖" --type question --amount 1 --prize "大奖" --duration 30

# JSON输出
npx polyv-live-cli@latest lottery create -c 3151318 --name "测试抽奖" --type none --amount 3 --prize "奖品" -o json
```

## 查询抽奖列表

```bash
# 查询频道所有抽奖活动
npx polyv-live-cli@latest lottery list -c 3151318

# 分页查询
npx polyv-live-cli@latest lottery list -c 3151318 --page 1 --size 20

# JSON输出
npx polyv-live-cli@latest lottery list -c 3151318 -o json
```

## 查询抽奖详情

```bash
# 获取指定抽奖活动详情
npx polyv-live-cli@latest lottery get -c 3151318 --id 20521

# JSON输出
npx polyv-live-cli@latest lottery get -c 3151318 --id 20521 -o json
```

## 更新抽奖

```bash
# 更新抽奖活动配置
npx polyv-live-cli@latest lottery update -c 3151318 --id 20521 --name "更新后的抽奖" --amount 5 --prize "新奖品"

# JSON输出
npx polyv-live-cli@latest lottery update -c 3151318 --id 20521 --amount 10 -o json
```

## 删除抽奖

```bash
# 删除指定抽奖活动
npx polyv-live-cli@latest lottery delete -c 3151318 --id 20521
```

## 查询中奖用户

```bash
# 查询中奖用户列表
npx polyv-live-cli@latest lottery winners -c 3151318 --lottery-id fv3mao43u6

# 分页查询
npx polyv-live-cli@latest lottery winners -c 3151318 --lottery-id fv3mao43u6 --page 1 --limit 20

# JSON输出
npx polyv-live-cli@latest lottery winners -c 3151318 --lottery-id fv3mao43u6 -o json
```

## 查询抽奖记录

```bash
# 查询频道抽奖记录
npx polyv-live-cli@latest lottery records -c 3151318

# 按场次筛选
npx polyv-live-cli@latest lottery records -c 3151318 --session-id fwly13xczv

# 按时间范围筛选
npx polyv-live-cli@latest lottery records -c 3151318 --start-time 1615772426000 --end-time 1615773566000

# 分页查询
npx polyv-live-cli@latest lottery records -c 3151318 --page 1 --limit 20

# JSON输出
npx polyv-live-cli@latest lottery records -c 3151318 -o json
```

## 命令选项

### lottery create

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--name` | 抽奖活动名称（必填） | - |
| `--type` | 抽奖条件类型（必填） | none/invite/duration/comment/question |
| `--amount` | 中奖人数（必填） | 数字 |
| `--prize` | 奖品名称（必填） | - |
| `--duration` | 抽奖时长（分钟） | 数字 |
| `--invite-num` | 邀请人数（仅invite类型） | 数字 |
| `--receive-info` | 中奖者信息收集配置 | JSON字符串 |
| `-o, --output` | 输出格式 | table（默认）/ json |

### lottery list

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--page` | 页码 | 数字，默认1 |
| `--size` | 每页数量 | 数字，默认10 |
| `-o, --output` | 输出格式 | table（默认）/ json |

### lottery get

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--id` | 抽奖活动ID（必填） | - |
| `-o, --output` | 输出格式 | table（默认）/ json |

### lottery update

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--id` | 抽奖活动ID（必填） | - |
| `--name` | 新的抽奖活动名称 | - |
| `--amount` | 新的中奖人数 | 数字 |
| `--prize` | 新的奖品名称 | - |
| `-o, --output` | 输出格式 | table（默认）/ json |

### lottery delete

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--id` | 抽奖活动ID（必填） | - |

### lottery winners

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--lottery-id` | 抽奖ID（必填） | - |
| `--page` | 页码 | 数字，默认1 |
| `--limit` | 每页数量 | 数字，默认20 |
| `-o, --output` | 输出格式 | table（默认）/ json |

### lottery records

| 选项 | 说明 | 格式 |
|------|------|------|
| `-c, --channel-id` | 频道ID（必填） | - |
| `--session-id` | 场次ID | - |
| `--start-time` | 开始时间（毫秒时间戳） | 数字 |
| `--end-time` | 结束时间（毫秒时间戳） | 数字 |
| `--page` | 页码 | 数字，默认1 |
| `--limit` | 每页数量 | 数字，默认20 |
| `-o, --output` | 输出格式 | table（默认）/ json |

## 抽奖条件类型说明

| 类型 | 说明 | 必需参数 |
|------|------|----------|
| `none` | 无条件抽奖（默认） | - |
| `invite` | 邀请好友参与 | `--invite-num`（邀请人数） |
| `duration` | 观看时长抽奖 | `--duration`（观看分钟数） |
| `comment` | 发表评论抽奖 | `--duration`（评论后分钟内） |
| `question` | 回答问题抽奖 | `--duration`（答题时长） |

## 输出格式

### Table 格式（默认）

抽奖列表示例：
```
┌──────────┬─────────────────────┬──────────┬────────┬────────┬───────────────────┐
│ ID       │ Name                │ Type     │ Status │ Amount │ Prize             │
├──────────┼─────────────────────┼──────────┼────────┼────────┼───────────────────┤
│ 20521    │ 幸运抽奖            │ none     │ ended  │ 3      │ 神秘礼品          │
│ 20522    │ 邀请抽奖            │ invite   │ active │ 5      │ 优惠券            │
└──────────┴─────────────────────┴──────────┴────────┴────────┴───────────────────┘
```

中奖用户示例：
```
┌────────────┬────────────┬─────────────┬─────────────────────┐
│ Viewer ID  │ Nickname   │ Winner Code │ Win Time            │
├────────────┼────────────┼─────────────┼─────────────────────┤
│ viewer123  │ Winner1    │ ABC123      │ 2024-03-19 10:00:00 │
└────────────┴────────────┴─────────────┴─────────────────────┘
```

### JSON 格式

使用 `-o json` 选项输出结构化JSON数据，便于脚本处理。

## 相关文档

- [频道管理](./channel-management.md) - 频道基础操作
- [签到管理](./checkin.md) - 签到互动功能
- [聊天管理](./chat-management.md) - 聊天消息管理
