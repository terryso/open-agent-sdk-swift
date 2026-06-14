# 观众信息查询命令

## 概述

观众信息查询命令用于通过 CLI 查询直播间观众数据，支持获取单个观众详情和分页查询观众列表。

## 命令列表

| 命令 | 说明 |
|------|------|
| `viewer get` | 获取单个观众详情 |
| `viewer list` | 分页查询观众列表 |

## viewer get - 获取观众详情

获取指定观众的详细信息，包括昵称、手机号、来源、观看时长等。

### 语法

```bash
npx polyv-live-cli@latest viewer get -i <观众ID> [-o table|json]
```

### 参数

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--viewer-id` | `-i` | 是 | 观众唯一 ID（viewerUnionId） |
| `--output` | `-o` | 否 | 输出格式：`table`（默认）或 `json` |

### 示例

```bash
# 获取观众详情（表格格式）
npx polyv-live-cli@latest viewer get -i "2_v378gn997yovtl3p8h77db9e224t6hg9"

# 获取观众详情（JSON格式）
npx polyv-live-cli@latest viewer get -i "2_v378gn997yovtl3p8h77db9e224t6hg9" -o json

# 使用完整参数名
npx polyv-live-cli@latest viewer get --viewer-id "2_v378gn997yovtl3p8h77db9e224t6hg9" --output json
```

### 输出字段

| 字段 | 说明 |
|------|------|
| Viewer ID | 观众唯一标识 |
| Nickname | 观众昵称 |
| Mobile | 手机号 |
| Source | 来源类型（IMPORT/WX/MOBILE） |
| Name | 采集姓名 |
| Email | 邮箱 |
| Area | 地址 |
| Watch Duration | 观看时长 |
| Watch Channels | 观看频道数 |
| Created Time | 创建时间 |

## viewer list - 查询观众列表

分页查询观众列表，支持按来源、手机号、邮箱、地址等条件过滤。

### 语法

```bash
npx polyv-live-cli@latest viewer list [选项]
```

### 参数

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--source` | - | 否 | 来源过滤：`IMPORT`（导入）、`WX`（微信）、`MOBILE`（手机） |
| `--mobile` | - | 否 | 按手机号过滤 |
| `--email` | - | 否 | 按邮箱过滤 |
| `--area` | - | 否 | 按地址过滤 |
| `--page` | - | 否 | 页码，默认 1 |
| `--size` | - | 否 | 每页数量，默认 10，最大 1000 |
| `--output` | `-o` | 否 | 输出格式：`table`（默认）或 `json` |

### 示例

```bash
# 查询所有观众（默认分页）
npx polyv-live-cli@latest viewer list

# 分页查询
npx polyv-live-cli@latest viewer list --page 1 --size 20

# 按来源过滤
npx polyv-live-cli@latest viewer list --source IMPORT
npx polyv-live-cli@latest viewer list --source WX
npx polyv-live-cli@latest viewer list --source MOBILE

# 按手机号过滤
npx polyv-live-cli@latest viewer list --mobile "13800138000"

# 按邮箱过滤
npx polyv-live-cli@latest viewer list --email "user@example.com"

# 按地址过滤
npx polyv-live-cli@latest viewer list --area "北京"

# 组合过滤条件
npx polyv-live-cli@latest viewer list --source IMPORT --page 1 --size 50 -o json

# JSON 格式输出
npx polyv-live-cli@latest viewer list --source WX -o json
```

### 输出字段

| 字段 | 说明 |
|------|------|
| Viewer ID | 观众唯一标识（截断显示） |
| Nickname | 观众昵称 |
| Mobile | 手机号 |
| Source | 来源类型 |
| Watch Duration | 观看时长 |
| Channels | 观看频道数 |
| Created Time | 创建时间 |

### JSON 输出格式

```json
{
  "pageNumber": 1,
  "pageSize": 10,
  "totalPages": 5,
  "totalItems": 47,
  "contents": [
    {
      "viewerUnionId": "2_v378gn997yovtl3p8h77db9e224t6hg9",
      "nickname": "张三",
      "mobile": "13800138000",
      "source": "IMPORT",
      "name": "张三",
      "email": "zhangsan@example.com",
      "area": "北京",
      "watchDuration": 3600,
      "watchChannelCount": 5,
      "createTime": 1704067200000
    }
  ]
}
```

## 观众来源类型

| 值 | 说明 |
|----|------|
| `IMPORT` | 批量导入的观众 |
| `WX` | 微信授权登录的观众 |
| `MOBILE` | 手机号登录的观众 |

## 错误处理

| 错误 | 说明 |
|------|------|
| `viewerId is required` | 未提供观众 ID |
| `page must be a positive integer` | 页码必须为正整数 |
| `size must be a positive integer` | 每页数量必须为正整数 |
| `size must not exceed 1000` | 每页数量不能超过 1000 |
| `output must be either "table" or "json"` | 输出格式无效 |

## API 参考

- 获取观众详情：`GET /live/v4/user/viewer-record/get`
- 获取观众列表：`GET /live/v4/user/viewer-record/list`

## 相关命令

- [聊天消息管理](chat-management.md) - 管理直播间聊天消息
- [签到管理](checkin.md) - 管理直播签到
- [抽奖管理](lottery.md) - 管理抽奖活动
