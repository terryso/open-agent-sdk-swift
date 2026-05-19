# 白名单管理命令

## 概述

白名单管理命令用于管理直播间的观看权限（白名单观看模式）。支持全局设置和频道级别设置。

白名单观看是一种观看条件认证方式，只有添加到白名单中的用户才能观看直播。白名单项包含会员码（手机号）和昵称（备注）。

## 命令列表

| 命令 | 说明 |
|------|------|
| `whitelist list` | 获取白名单列表 |
| `whitelist add` | 添加白名单项 |
| `whitelist update` | 更新白名单项 |
| `whitelist remove` | 删除白名单项 |

## 通用参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--rank <number>` | 条件级别：1=主要条件，2=次要条件 | 是 |
| `--channel-id <id>` | 频道ID（不传为全局设置） | 否 |
| `-o, --output <format>` | 输出格式：table（默认）或 json | 否 |

## whitelist list - 获取白名单列表

获取白名单列表，支持分页和关键词搜索。

### 语法

```bash
npx polyv-live-cli@latest whitelist list --rank <1|2> [options]
```

### 参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--rank <number>` | 条件级别：1=主要条件，2=次要条件 | 是 |
| `--channel-id <id>` | 频道ID（不传为全局设置） | 否 |
| `--page <number>` | 页码，默认为1 | 否 |
| `--page-size <number>` | 每页数量，默认为10 | 否 |
| `--keyword <keyword>` | 关键词（可根据会员码和名称查询） | 否 |
| `-o, --output <format>` | 输出格式：table（默认）或 json | 否 |

### 示例

```bash
# 获取全局白名单
npx polyv-live-cli@latest whitelist list --rank 1

# 获取频道白名单
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1

# 分页查询
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 --page 1 --page-size 20

# 关键词搜索
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 --keyword "张三"

# JSON格式输出
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 -o json
```

### 输出示例

**表格格式：**
```
找到 2 条白名单记录 (channel 3151318)
页码: 1 / 1
┌──────────────┬──────────┐
│ 会员码        │ 昵称      │
├──────────────┼──────────┤
│ 13800138000  │ 张三      │
│ 13900139000  │ 李四      │
└──────────────┴──────────┘
```

**JSON格式：**
```json
{
  "pageNumber": 1,
  "totalPages": 1,
  "pageSize": 10,
  "contents": [
    { "name": "张三", "phone": "13800138000" },
    { "name": "李四", "phone": "13900139000" }
  ]
}
```

## whitelist add - 添加白名单项

添加单个白名单项。

### 语法

```bash
npx polyv-live-cli@latest whitelist add --rank <1|2> --code <会员码> [options]
```

### 参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--rank <number>` | 条件级别：1=主要条件，2=次要条件 | 是 |
| `--code <code>` | 会员码（最多50个字符） | 是 |
| `--channel-id <id>` | 频道ID（不传为全局设置） | 否 |
| `--name <name>` | 昵称/备注（最多50个字符） | 否 |
| `-o, --output <format>` | 输出格式：table（默认）或 json | 否 |

### 示例

```bash
# 添加频道白名单
npx polyv-live-cli@latest whitelist add --channel-id 3151318 --rank 1 --code "13800138000" --name "张三"

# 添加全局白名单
npx polyv-live-cli@latest whitelist add --rank 1 --code "13800138000" --name "张三"

# JSON格式输出
npx polyv-live-cli@latest whitelist add --rank 1 --code "13800138000" --name "张三" -o json
```

### 输出示例

**表格格式：**
```
Successfully added whitelist item for channel 3151318
```

**JSON格式：**
```json
{
  "success": true,
  "message": "白名单添加成功",
  "code": "13800138000",
  "channelId": "3151318"
}
```

## whitelist update - 更新白名单项

更新单个白名单项。需要提供原会员码（old-code）来标识要更新的记录。

### 语法

```bash
npx polyv-live-cli@latest whitelist update --rank <1|2> --old-code <原会员码> --code <新会员码> [options]
```

### 参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--rank <number>` | 条件级别：1=主要条件，2=次要条件 | 是 |
| `--old-code <code>` | 原会员码（用于定位要更新的记录） | 是 |
| `--code <code>` | 新会员码（最多50个字符） | 是 |
| `--channel-id <id>` | 频道ID（不传为全局设置） | 否 |
| `--name <name>` | 新昵称/备注（最多50个字符） | 否 |
| `-o, --output <format>` | 输出格式：table（默认）或 json | 否 |

### 示例

```bash
# 更新频道白名单
npx polyv-live-cli@latest whitelist update --channel-id 3151318 --rank 1 --old-code "13800138000" --code "13900139000" --name "李四"

# 更新全局白名单
npx polyv-live-cli@latest whitelist update --rank 1 --old-code "13800138000" --code "13900139000" --name "李四"

# JSON格式输出
npx polyv-live-cli@latest whitelist update --rank 1 --old-code "13800138000" --code "13900139000" -o json
```

### 输出示例

**表格格式：**
```
Successfully updated whitelist item for channel 3151318
```

**JSON格式：**
```json
{
  "success": true,
  "message": "白名单更新成功",
  "oldCode": "13800138000",
  "newCode": "13900139000",
  "channelId": "3151318"
}
```

## whitelist remove - 删除白名单项

删除白名单项，支持单个删除和清空所有。

### 语法

```bash
npx polyv-live-cli@latest whitelist remove --rank <1|2> [options]
```

### 参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--rank <number>` | 条件级别：1=主要条件，2=次要条件 | 是 |
| `--channel-id <id>` | 频道ID（不传为全局设置） | 否 |
| `--codes <codes>` | 要删除的会员码（目前只支持单个值） | 否* |
| `--clear` | 清空所有白名单 | 否* |
| `-o, --output <format>` | 输出格式：table（默认）或 json | 否 |

*必须指定 `--codes` 或 `--clear` 其中之一

### 示例

```bash
# 删除单个白名单
npx polyv-live-cli@latest whitelist remove --channel-id 3151318 --rank 1 --codes "13800138000"

# 清空所有白名单
npx polyv-live-cli@latest whitelist remove --channel-id 3151318 --rank 1 --clear

# JSON格式输出
npx polyv-live-cli@latest whitelist remove --rank 1 --codes "13800138000" -o json
```

### 输出示例

**表格格式（删除）：**
```
Successfully removed 1 whitelist item for channel 3151318
```

**表格格式（批量删除）：**
```
Successfully removed 3 whitelist items for channel 3151318
```

**表格格式（清空）：**
```
Successfully cleared all whitelist items for channel 3151318
```

**JSON格式：**
```json
{
  "success": true,
  "message": "白名单删除成功",
  "codes": "13800138000,13900139000",
  "clear": false,
  "channelId": "3151318"
}
```

## 错误处理

| 错误消息 | 原因 | 解决方案 |
|---------|------|---------|
| `rank 必须是 1 (主要条件) 或 2 (次要条件)` | rank 参数不是 1 或 2 | 使用有效的 rank 值 |
| `code (会员码) 是必需的` | 添加时未提供 code | 添加 --code 参数 |
| `old-code (原会员码) 是必需的` | 更新时未提供 old-code | 添加 --old-code 参数 |
| `必须指定 --codes 或使用 --clear 清空所有` | 删除时未提供 codes 或 clear | 添加 --codes 或 --clear 参数 |
| `code 不能超过50个字符` | code 超过长度限制 | 缩短 code 内容 |
| `name 不能超过50个字符` | name 超过长度限制 | 缩短 name 内容 |

## 使用场景

### 场景1：设置白名单观看模式

```bash
# 1. 设置观看条件为白名单模式
npx polyv-live-cli@latest watch-condition set --channel-id 3151318 --rank 1 --auth-type phone --enabled Y

# 2. 添加白名单用户
npx polyv-live-cli@latest whitelist add --channel-id 3151318 --rank 1 --code "13800138000" --name "VIP用户1"
npx polyv-live-cli@latest whitelist add --channel-id 3151318 --rank 1 --code "13900139000" --name "VIP用户2"

# 3. 验证白名单列表
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1
```

### 场景2：批量管理白名单

```bash
# 批量添加（需逐个添加）
for phone in 13800138001 13800138002 13800138003; do
  npx polyv-live-cli@latest whitelist add --channel-id 3151318 --rank 1 --code "$phone"
done

# 搜索特定用户
npx polyv-live-cli@latest whitelist list --channel-id 3151318 --rank 1 --keyword "138001380"

# 批量删除（需逐个删除）
for phone in 13800138001 13800138002 13800138003; do
  npx polyv-live-cli@latest whitelist remove --channel-id 3151318 --rank 1 --codes "$phone"
done
```

### 场景3：直播结束后清理

```bash
# 清空所有白名单
npx polyv-live-cli@latest whitelist remove --channel-id 3151318 --rank 1 --clear

# 关闭白名单观看模式
npx polyv-live-cli@latest watch-condition set --channel-id 3151318 --rank 1 --auth-type none --enabled Y
```

## 注意事项

1. **全局设置 vs 频道设置**：不传 `--channel-id` 时为全局设置，传 `--channel-id` 时为频道级别设置
2. **rank 参数**：必须指定 rank（1=主要条件，2=次要条件），与观看条件配置对应
3. **白名单观看前提**：需要先通过 `watch-condition set` 命令设置认证类型为 `phone`（白名单观看）
4. **字符限制**：code 和 name 最多50个字符
5. **更新操作**：需要提供 `--old-code` 来定位要更新的记录
6. **删除限制**：`--codes` 参数目前只支持单个会员码（API限制），如需删除多个请逐个调用或使用 `--clear` 清空所有
