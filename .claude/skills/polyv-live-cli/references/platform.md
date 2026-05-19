# 平台账号信息管理命令

## 概述

平台账号信息管理命令用于查看和配置保利威账号的基本信息和开关配置。

## 命令列表

| 命令 | 描述 |
|------|------|
| `platform get` | 获取账号基本信息 |
| `platform switch get` | 获取账号开关配置 |
| `platform switch update` | 更新账号开关配置 |
| `platform callback get` | 获取回调设置 |
| `platform callback update` | 更新回调设置 |
| `platform setting get` | 获取全局频道设置 |
| `platform setting update` | 更新全局频道设置 |

## platform get

获取账号基本信息，包括用户ID、邮箱、频道数、连麦限制等。

### 用法

```bash
npx polyv-live-cli@latest platform get [选项]
```

### 选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--output` | `-o` | 输出格式 (table\|json) | table |

### 示例

```bash
# 获取账号基本信息（表格格式）
npx polyv-live-cli@latest platform get

# 获取账号基本信息（JSON格式）
npx polyv-live-cli@latest platform get -o json
```

### 输出字段说明

| 字段 | 描述 |
|------|------|
| 用户 ID | 保利威账号的用户ID |
| 邮箱 | 账号绑定的邮箱地址 |
| 最大频道数 | 账号可创建的最大频道数量 |
| 总频道数 | 当前已创建的频道总数 |
| 可用频道数 | 剩余可创建的频道数量 |
| 连麦限制 | 连麦功能的限制数 |
| 观看域名 | 自定义观看域名（如已配置） |

### JSON 输出示例

```json
{
  "userId": "user123",
  "email": "admin@example.com",
  "maxChannels": 100,
  "totalChannels": 10,
  "availableChannels": 90,
  "linkMicLimit": 10,
  "watchDomain": "https://live.example.com"
}
```

---

## platform switch get

获取账号的开关配置状态，包括全局设置、认证、录制、回放、弹幕等开关状态。

### 用法

```bash
npx polyv-live-cli@latest platform switch get [选项]
```

### 选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--output` | `-o` | 输出格式 (table\|json) | table |

### 示例

```bash
# 获取开关配置（表格格式）
npx polyv-live-cli@latest platform switch get

# 获取开关配置（JSON格式）
npx polyv-live-cli@latest platform switch get -o json
```

### 输出字段说明

| 开关名称 | 描述 |
|----------|------|
| 全局设置 | 全局设置开关状态 |
| 认证 | 认证功能开关状态 |
| 录制 | 自动录制开关状态 |
| 回放 | 回放功能开关状态 |
| 弹幕 | 弹幕功能开关状态 |

### JSON 输出示例

```json
{
  "config": {
    "globalSettingEnabled": true,
    "authEnabled": false,
    "recordEnabled": true,
    "playbackEnabled": true,
    "danmuEnabled": false
  }
}
```

---

## platform switch update

更新账号的开关配置。

### 用法

```bash
npx polyv-live-cli@latest platform switch update --param <参数名> --enabled <Y|N> [选项]
```

### 选项

| 选项 | 简写 | 描述 | 必需 | 默认值 |
|------|------|------|------|--------|
| `--param` | - | 开关参数名称 | 是 | - |
| `--enabled` | - | 启用状态 (Y\|N) | 是 | - |
| `--output` | `-o` | 输出格式 (table\|json) | 否 | table |

### 可用参数

| 参数名 | 描述 |
|--------|------|
| `globalSettingEnabled` | 全局设置开关 |
| `authEnabled` | 认证开关 |
| `recordEnabled` | 录制开关 |
| `playbackEnabled` | 回放开关 |
| `danmuEnabled` | 弹幕开关 |

### 示例

```bash
# 启用认证功能
npx polyv-live-cli@latest platform switch update --param authEnabled --enabled Y

# 禁用录制功能
npx polyv-live-cli@latest platform switch update --param recordEnabled --enabled N

# 启用弹幕功能（JSON输出）
npx polyv-live-cli@latest platform switch update --param danmuEnabled --enabled Y -o json
```

### 错误处理

| 错误情况 | 错误信息 |
|----------|----------|
| 参数为空 | `param (配置项名称) 是必需的` |
| enabled 值无效 | `enabled 必须是 Y 或 N` |
| 不支持的参数 | `不支持的配置项: xxx。可用配置项: globalSettingEnabled, authEnabled, recordEnabled, playbackEnabled, danmuEnabled` |

---

## API 映射

| CLI 命令 | SDK 方法 | API 端点 |
|----------|----------|----------|
| `platform get` | `account.getUserInfo()` | `/live/v3/user/get-info` |
| `platform switch get` | `account.switchGet()` | `/live/v3/user/switch/get` |
| `platform switch update` | `account.switchUpdate()` | `/live/v3/user/switch/update` |
| `platform callback get` | `v4User.getCallback()` | `/live/v4/user/callback/get` |
| `platform callback update` | `v4User.updateCallback()` | `/live/v4/user/callback/update` |
| `platform setting get` | `v4User.getGlobalChannelSettings()` | `/live/v4/user/global-setting/switch/get` |
| `platform setting update` | `v4User.updateGlobalChannelSettings()` | `/live/v4/user/global-setting/switch/update` |

---

## platform callback get

获取回调设置，包括回调URL和启用状态。

### 用法

```bash
npx polyv-live-cli@latest platform callback get [选项]
```

### 选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--output` | `-o` | 输出格式 (table\|json) | table |

### 示例

```bash
# 获取回调设置（表格格式）
npx polyv-live-cli@latest platform callback get

# 获取回调设置（JSON格式）
npx polyv-live-cli@latest platform callback get -o json
```

### 输出字段说明

| 字段 | 描述 |
|------|------|
| 回调 URL | 接收回调通知的URL地址 |
| 是否启用 | 回调功能是否启用（是/否） |

### JSON 输出示例

```json
{
  "url": "https://example.com/callback",
  "enabled": true
}
```

---

## platform callback update

更新回调设置，可以更新回调URL和启用状态。

### 用法

```bash
npx polyv-live-cli@latest platform callback update [选项]
```

### 选项

| 选项 | 简写 | 描述 | 必需 | 默认值 |
|------|------|------|------|--------|
| `--url` | - | 回调URL（必须以 http:// 或 https:// 开头） | 否 | - |
| `--enabled` | - | 启用状态 (Y\|N) | 否 | - |
| `--output` | `-o` | 输出格式 (table\|json) | 否 | table |

**注意：** 至少需要提供一个选项（`--url` 或 `--enabled`）。

### 示例

```bash
# 更新回调URL
npx polyv-live-cli@latest platform callback update --url https://example.com/callback

# 启用回调
npx polyv-live-cli@latest platform callback update --enabled Y

# 禁用回调
npx polyv-live-cli@latest platform callback update --enabled N

# 同时更新URL和启用状态
npx polyv-live-cli@latest platform callback update --url https://example.com/callback --enabled Y

# JSON格式输出
npx polyv-live-cli@latest platform callback update --url https://example.com/callback -o json
```

### 错误处理

| 错误情况 | 错误信息 |
|----------|----------|
| 无参数提供 | `至少需要提供 url 或 enabled 参数` |
| URL格式错误 | `url 必须以 http:// 或 https:// 开头` |
| enabled值无效 | `enabled 必须是 Y 或 N` |

---

## platform setting get

获取全局频道设置，包括并发观看人数、自动转码、打赏等功能的状态。

### 用法

```bash
npx polyv-live-cli@latest platform setting get [选项]
```

### 选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--output` | `-o` | 输出格式 (table\|json) | table |

### 示例

```bash
# 获取全局频道设置（表格格式）
npx polyv-live-cli@latest platform setting get

# 获取全局频道设置（JSON格式）
npx polyv-live-cli@latest platform setting get -o json
```

### 输出字段说明

| 设置项 | 描述 |
|--------|------|
| 最大并发观看人数 | 最大并发观看人数开关（开启/禁用） |
| 自动转码 | 自动转码功能开关 |
| 打赏功能 | 打赏功能开关 |
| 转存自动上传 | 转存自动上传PPT开关 |
| 转存自动转码 | 转存自动转码开关 |
| PPT全屏 | PPT全屏显示开关 |
| 封面图片类型 | 播放器封面图片类型（contain/cover） |
| 测试模式按钮 | 测试模式按钮开关 |

### JSON 输出示例

```json
{
  "channelConcurrencesEnabled": "Y",
  "timelyConvertEnabled": "Y",
  "donateEnabled": "N",
  "rebirthAutoUploadEnabled": "N",
  "rebirthAutoConvertEnabled": "N",
  "pptCoveredEnabled": "N",
  "coverImgType": "contain",
  "testModeButtonEnabled": "N"
}
```

---

## platform setting update

更新全局频道设置，可以同时更新多个设置项。

### 用法

```bash
npx polyv-live-cli@latest platform setting update [选项]
```

### 选项

| 选项 | 描述 | 值 |
|------|------|------|
| `--channel-concurrences-enabled` | 最大并发观看人数开关 | Y/N |
| `--timely-convert-enabled` | 自动转码开关 | Y/N |
| `--donate-enabled` | 打赏功能开关 | Y/N |
| `--rebirth-auto-upload-enabled` | 转存自动上传PPT | Y/N |
| `--rebirth-auto-convert-enabled` | 转存自动转码 | Y/N |
| `--ppt-covered-enabled` | PPT全屏开关 | Y/N |
| `--cover-img-type` | 封面图片类型 | contain/cover |
| `--test-mode-button-enabled` | 测试模式按钮 | Y/N |
| `--output` | 输出格式 (table\|json) | table |

**注意：** 至少需要提供一个设置选项。

### 示例

```bash
# 更新单个设置
npx polyv-live-cli@latest platform setting update --channel-concurrences-enabled Y

# 更新多个设置
npx polyv-live-cli@latest platform setting update \
  --channel-concurrences-enabled Y \
  --timely-convert-enabled Y \
  --donate-enabled N

# 更新封面图片类型
npx polyv-live-cli@latest platform setting update --cover-img-type contain

# JSON格式输出
npx polyv-live-cli@latest platform setting update --donate-enabled Y -o json
```

### 错误处理

| 错误情况 | 错误信息 |
|----------|----------|
| 无参数提供 | `至少需要提供一个参数 (At least one parameter is required)` |
| Y/N值无效 | `xxx 必须是 Y 或 N` |
| 封面类型无效 | `coverImgType 必须是 contain 或 cover` |

---

## API 映射

- [身份认证配置](authentication.md)
- [频道管理](channel-management.md)
- [录制设置](record-settings.md)
