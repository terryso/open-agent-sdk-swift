# 聊天消息管理

本文档详细介绍保利威直播 CLI 的聊天消息管理命令。

## 命令概览

```bash
npx polyv-live-cli@latest chat <子命令> [选项]
```

## 子命令

### chat send - 发送管理员消息

向指定频道发送管理员消息（文本或图片）。

```bash
npx polyv-live-cli@latest chat send -c <频道ID> [选项]
```

#### 必需选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID |

#### 可选选项

| 选项 | 说明 |
|------|------|
| `-m, --msg <文本>` | 文本消息内容 |
| `-i, --img-url <url>` | 图片 URL |
| `-p, --pic <url>` | 发送者头像 URL |
| `-n, --nickname <名称>` | 发送者昵称 |
| `-a, --actor <角色>` | 发送者角色 |
| `--admin-index <数字>` | 管理员索引 |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

> 注意：`-m` 和 `-i` 至少需要提供一个。

#### 示例

```bash
# 发送文本消息
npx polyv-live-cli@latest chat send -c 3151318 -m "欢迎观看直播！"

# 发送图片消息
npx polyv-live-cli@latest chat send -c 3151318 -i "https://example.com/image.png"

# 发送带自定义昵称的消息
npx polyv-live-cli@latest chat send -c 3151318 -m "大家好" -n "主播" -a "主持人"

# JSON 格式输出
npx polyv-live-cli@latest chat send -c 3151318 -m "测试消息" -o json
```

---

### chat list - 查看聊天历史

获取指定频道的聊天消息历史记录。

```bash
npx polyv-live-cli@latest chat list -c <频道ID> [选项]
```

#### 必需选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID |

#### 可选选项

| 选项 | 说明 |
|------|------|
| `--start-day <日期>` | 开始日期筛选（格式：yyyy-MM-dd） |
| `--end-day <日期>` | 结束日期筛选（格式：yyyy-MM-dd） |
| `--page <数字>` | 页码（默认 1） |
| `--size <数字>` | 每页数量，1-100（默认 20） |
| `--user-type <类型>` | 用户类型筛选 |
| `--status <状态>` | 消息状态筛选 |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 查看最近聊天消息
npx polyv-live-cli@latest chat list -c 3151318

# 分页查看
npx polyv-live-cli@latest chat list -c 3151318 --page 2 --size 50

# 按日期范围筛选
npx polyv-live-cli@latest chat list -c 3151318 --start-day 2024-01-01 --end-day 2024-01-31

# JSON 格式输出
npx polyv-live-cli@latest chat list -c 3151318 -o json
```

#### 表格输出字段

| 字段 | 说明 |
|------|------|
| Message ID | 消息唯一标识 |
| Content | 消息内容（过长会截断） |
| Time | 消息发送时间 |
| Sender | 发送者昵称 |
| User Type | 发送者类型 |

---

### chat delete - 删除消息

删除单条消息或清空频道所有聊天消息。

```bash
npx polyv-live-cli@latest chat delete -c <频道ID> [选项]
```

#### 必需选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID |

#### 可选选项

| 选项 | 说明 |
|------|------|
| `-m, --message-id <id>` | 要删除的消息 ID |
| `--clear` | 清空该频道所有聊天消息 |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

> 注意：如果使用 `--clear`，则不需要指定 `--message-id`。

#### 示例

```bash
# 删除单条消息
npx polyv-live-cli@latest chat delete -c 3151318 -m abc123

# 清空所有消息
npx polyv-live-cli@latest chat delete -c 3151318 --clear
```

> 警告：删除操作不可恢复，执行前会有确认提示。

---

## 禁言踢人管理 (Story 11-2)

### chat ban - 禁言用户

禁言指定用户，支持频道级别和账号级别（全局）。

```bash
npx polyv-live-cli@latest chat ban [选项]
```

#### 选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID（频道级别禁言时必需） |
| `-u, --user-ids <ids>` | 用户 ID，多个用逗号分隔（必需） |
| `--global` | 全局禁言（账号级别） |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 频道级别禁言
npx polyv-live-cli@latest chat ban -c 3151318 -u user1,user2

# 全局禁言
npx polyv-live-cli@latest chat ban -u user1,user2 --global

# JSON 格式输出
npx polyv-live-cli@latest chat ban -c 3151318 -u user1 -o json
```

---

### chat unban - 解除禁言

解除用户的禁言状态。

```bash
npx polyv-live-cli@latest chat unban [选项]
```

#### 选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID（频道级别解禁时必需） |
| `-u, --user-ids <ids>` | 用户 ID，多个用逗号分隔（必需） |
| `--global` | 全局解禁（账号级别） |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 频道级别解禁
npx polyv-live-cli@latest chat unban -c 3151318 -u user1,user2

# 全局解禁
npx polyv-live-cli@latest chat unban -u user1,user2 --global
```

---

### chat kick - 踢人

将用户踢出直播间，支持频道级别和账号级别（全局）。

```bash
npx polyv-live-cli@latest chat kick [选项]
```

#### 选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID（频道级别踢人时必需） |
| `--viewer-ids <ids>` | 观众 ID，多个用逗号分隔 |
| `-n, --nick-names <names>` | 观众昵称，多个用逗号分隔 |
| `--global` | 全局踢人（账号级别） |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

> 注意：`--viewer-ids` 和 `-n` 至少需要提供一个。

#### 示例

```bash
# 频道级别踢人
npx polyv-live-cli@latest chat kick -c 3151318 --viewer-ids viewer1,viewer2 -n Nick1,Nick2

# 全局踢人
npx polyv-live-cli@latest chat kick --viewer-ids viewer1 --global

# JSON 格式输出
npx polyv-live-cli@latest chat kick -c 3151318 --viewer-ids viewer1 -o json
```

---

### chat unkick - 解除踢人

解除用户的踢人状态，允许重新进入直播间。

```bash
npx polyv-live-cli@latest chat unkick [选项]
```

#### 选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID（频道级别解踢时必需） |
| `--viewer-ids <ids>` | 观众 ID，多个用逗号分隔 |
| `-n, --nick-names <names>` | 观众昵称，多个用逗号分隔 |
| `--global` | 全局解踢（账号级别） |
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 频道级别解踢
npx polyv-live-cli@latest chat unkick -c 3151318 --viewer-ids viewer1 -n Nick1

# 全局解踢
npx polyv-live-cli@latest chat unkick --viewer-ids viewer1 --global
```

---

### chat banned list - 查看禁言列表

查看频道的禁言用户、禁言 IP 或禁言词列表。

```bash
npx polyv-live-cli@latest chat banned list -c <频道ID> [选项]
```

#### 必需选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID |
| `--type <类型>` | 列表类型：userId（用户）、ip（IP地址）、badword（禁言词） |

#### 可选选项

| 选项 | 说明 |
|------|------|
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 查看禁言用户列表
npx polyv-live-cli@latest chat banned list -c 3151318 --type userId

# 查看禁言 IP 列表
npx polyv-live-cli@latest chat banned list -c 3151318 --type ip

# 查看禁言词列表
npx polyv-live-cli@latest chat banned list -c 3151318 --type badword

# JSON 格式输出
npx polyv-live-cli@latest chat banned list -c 3151318 --type userId -o json
```

---

### chat kicked list - 查看踢人列表

查看频道被踢出的用户列表。

```bash
npx polyv-live-cli@latest chat kicked list -c <频道ID> [选项]
```

#### 必需选项

| 选项 | 说明 |
|------|------|
| `-c, --channel-id <id>` | 频道 ID |

#### 可选选项

| 选项 | 说明 |
|------|------|
| `-o, --output <格式>` | 输出格式：table（默认）或 json |

#### 示例

```bash
# 查看踢人列表
npx polyv-live-cli@latest chat kicked list -c 3151318

# JSON 格式输出
npx polyv-live-cli@latest chat kicked list -c 3151318 -o json
```

---

## 常见工作流程

### 1. 发送直播公告

```bash
# 发送开播公告
npx polyv-live-cli@latest chat send -c 3151318 -m "直播即将开始，请稍候..." -n "系统公告" -a "管理员"
```

### 2. 查看并管理聊天记录

```bash
# 查看今天的聊天记录
npx polyv-live-cli@latest chat list -c 3151318 --start-day 2024-01-15 --end-day 2024-01-15

# 如果发现不当内容，删除该消息
npx polyv-live-cli@latest chat delete -c 3151318 -m <消息ID>
```

### 3. 直播结束后清理聊天

```bash
# 清空所有聊天消息
npx polyv-live-cli@latest chat delete -c 3151318 --clear
```

## 错误处理

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `channelId is required` | 未指定频道 ID | 使用 `-c` 参数指定频道 |
| `msg or imgUrl is required` | 发送消息时未提供内容 | 使用 `-m` 或 `-i` 参数 |
| `messageId is required when --clear is not specified` | 删除时未指定消息 ID | 使用 `-m` 参数或 `--clear` 选项 |

## API 参考

相关 API 文档：
- [发送管理员消息](https://help.polyv.net/#/live/api/chat/send_admin_msg)
- [获取聊天历史](https://help.polyv.net/#/live/api/chat/get_history)
- [删除聊天消息](https://help.polyv.net/#/live/api/chat/del_chat)
- [清空聊天记录](https://help.polyv.net/#/live/api/chat/clean_chat)
