# 观看条件配置命令

## 概述

观看条件配置命令用于管理直播间的观看权限设置，支持获取和设置观看条件。 可配置多种认证方式，如密码观看、付费观看、白名单观看、登记观看等。

## 命令列表

| 命令 | 说明 |
|------|------|
| `watch-condition get` | 获取观看条件配置 |
| `watch-condition set` | 设置观看条件配置 |

## watch-condition get - 获取观看条件

获取当前频道或全局的观看条件配置信息。

### 语法

```bash
npx polyv-live-cli@latest watch-condition get [--channel-id <ID>] [-o table|json]
```

### 参数

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--channel-id` | | 否 | 频道ID， 不传则获取全局设置 |
| `--output` | `-o` | 否 | 输出格式： `table`（默认）或 `json` |

### 示例

```bash
# 获取频道观看条件（表格格式）
npx polyv-live-cli@latest watch-condition get --channel-id 123456

# 获取全局观看条件设置
npx polyv-live-cli@latest watch-condition get

# 获取观看条件（JSON格式）
npx polyv-live-cli@latest watch-condition get --channel-id 123456 -o json
```

### 输出字段

| 字段 | 说明 |
|------|------|
| 条件级别 | 主要 (1) 或 次要 (2) |
| 状态 | 启用 (Y) 或 禁用 (N) |
| 认证类型 | 认证方式（无限制、密码观看、付费观看等） |
| 详细配置 | 根据认证类型显示具体配置 |

## watch-condition set - 设置观看条件

设置频道或全局的观看条件配置。

### 语法

```bash
npx polyv-live-cli@latest watch-condition set [options]
```

### 参数

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--channel-id` | | 否 | 频道ID， 不传则设置全局 |
| `--rank` | | 否 | 条件级别: `1` (主要) 或 `2` (次要)， 默认 `1` |
| `--auth-type` | | 否 | 认证类型（见下表） |
| `--enabled` | | 否 | 是否启用: `Y` 或 `N`， 默认 `Y` |
| `--auth-code` | | 否 | 密码（auth-type 为 code 时使用） |
| `--price` | | 否 | 价格/元（auth-type 为 pay 时使用） |
| `--config-file` | | 否 | JSON 配置文件路径（复杂配置时使用） |
| `--output` | `-o` | 否 | 输出格式: `table`（默认）或 `json` |

### 认证类型 (auth-type)

| 值 | 说明 | 所需额外参数 |
|------|------|------|
| `none` | 无限制（公开观看） | - |
| `code` | 密码观看 | `--auth-code` |
| `pay` | 付费观看 | `--price` |
| `phone` | 白名单观看 | - |
| `info` | 登记观看 | 需通过配置文件设置 |
| `custom` | 自定义授权 | 需通过配置文件设置 |
| `external` | 外部授权 | 需通过配置文件设置 |
| `direct` | 独立授权 | 需通过配置文件设置 |

### 示例

```bash
# 设置公开观看（无限制）
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --auth-type none --enabled Y

# 设置密码观看
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --auth-type code --enabled Y --auth-code "abc123"

# 设置付费观看（99.9元）
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --auth-type pay --enabled Y --price 99.9

# 禁用主要观看条件
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --enabled N

# 使用配置文件设置复杂条件
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --config-file ./watch-condition.json
```

### 配置文件格式

使用 `--config-file` 参数时，JSON 文件格式如下：

```json
{
  "authSettings": [
    {
      "rank": 1,
      "authType": "code",
      "enabled": "Y",
      "authCode": "password123"
    },
    {
      "rank": 2,
      "authType": "info",
      "enabled": "Y",
      "infoFields": [
        { "type": "name", "name": "姓名" },
        { "type": "mobile", "name": "手机号", "sms": "Y" }
      ]
    }
  ]
}
```

## 常见用例

### 1. 开启密码观看

```bash
# 设置主要条件为密码观看
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --auth-type code --auth-code "mypassword" --enabled Y
```

### 2. 设置付费直播

```bash
# 设置付费观看（19.9元）
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --rank 1 --auth-type pay --price 19.9 --enabled Y
```

### 3. 配置多级认证

使用配置文件设置主要和次要观看条件：

```json
{
  "authSettings": [
    {
      "rank": 1,
      "authType": "code",
      "enabled": "Y",
      "code": "vip123"
    },
    {
      "rank": 2,
      "authType": "info",
      "enabled": "Y",
      "infoFields": [
        { "type": "name", "name": "姓名", "placeholder": "请输入姓名" },
        { "type": "mobile", "name": "手机号", "sms": "Y" }
      ]
    }
  ]
}
```

```bash
npx polyv-live-cli@latest watch-condition set --channel-id 123456 --config ./auth-config.json
```

## 注意事项

1. **认证优先级**: 主要条件 (rank=1) 优先于次要条件 (rank=2)
2. **全局设置**: 不传 `--channel-id` 时操作的是全局默认设置
3. **禁用条件**: 设置 `--enabled N` 可以禁用某个级别的观看条件
4. **价格单位**: `--price` 参数单位为元，会自动转换为分
5. **配置文件**: 复杂配置建议使用 JSON 文件方式
