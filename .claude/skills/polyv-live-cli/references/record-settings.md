# 录制设置命令

## 概述

录制设置命令用于管理直播频道的回放设置和录制文件转存。支持查询和修改回放配置、将录制文件转存到点播、设置默认回放视频等操作。

## 命令列表

### record setting get

查询频道回放设置。

```bash
npx polyv-live-cli@latest record setting get -c <频道ID> [-o table|json]
```

**参数：**
- `-c, --channel-id <channelId>` - 频道ID（必填）
- `-o, --output <format>` - 输出格式：table（默认）或 json

**示例：**

```bash
# 查询频道回放设置
npx polyv-live-cli@latest record setting get -c 2588188

# JSON格式输出
npx polyv-live-cli@latest record setting get -c 2588188 -o json
```

**响应字段：**
| 字段 | 说明 |
|------|------|
| channelId | 频道号 |
| playbackEnabled | 回放开关：Y(开启)、N(关闭) |
| type | 回放类型：single(单个回放)、list(列表回放) |
| origin | 回放来源：record(录制)、playback(回放列表)、vod(点播列表) |
| videoId | 回放视频ID |
| videoName | 回放视频名称 |
| sectionEnabled | 章节开关 |
| globalSettingEnabled | 是否应用通用设置 |
| playbackMultiplierEnabled | 倍数播放开关 |
| playbackProgressBarEnabled | 进度条开关 |

---

### record setting set

修改频道回放设置。

```bash
npx polyv-live-cli@latest record setting set -c <频道ID> [选项]
```

**参数：**
- `-c, --channel-id <channelId>` - 频道ID（必填）
- `--playback-enabled <Y|N>` - 回放开关
- `--type <single|list>` - 回放类型
- `--origin <record|playback|vod|material>` - 回放来源
- `--video-id <videoId>` - 视频ID（当origin为playback或vod时需要）
- `--global-setting-enabled <Y|N>` - 是否使用通用设置
- `--section-enabled <Y|N>` - 章节开关
- `--playback-multiplier-enabled <Y|N>` - 倍数播放开关
- `--playback-progress-bar-enabled <Y|N>` - 进度条开关
- `--chat-playback-enabled <Y|N>` - 聊天互动重现开关
- `-o, --output <format>` - 输出格式

**示例：**

```bash
# 开启回放
npx polyv-live-cli@latest record setting set -c 2588188 --playback-enabled Y

# 设置为单个回放模式，来源为回放列表
npx polyv-live-cli@latest record setting set -c 2588188 --type single --origin playback --video-id 73801f70c8

# 关闭回放
npx polyv-live-cli@latest record setting set -c 2588188 --playback-enabled N
```

---

### record convert

将录制文件转存到点播（同步模式）。

```bash
npx polyv-live-cli@latest record convert -c <频道ID> --file-name <文件名> [选项]
```

**参数：**
- `-c, --channel-id <channelId>` - 频道ID（必填）
- `--file-name <fileName>` - 转存后的文件名（必填）
- `--session-id <sessionId>` - 源场次ID
- `--to-play-list <Y|N>` - 是否存入回放列表
- `--set-as-default <Y|N>` - 是否设为默认回放
- `--callback-url <url>` - 回调URL
- `--async` - 使用异步模式转存
- `-o, --output <format>` - 输出格式

**示例：**

```bash
# 同步转存录制文件
npx polyv-live-cli@latest record convert -c 2588188 --file-name "直播回放20240320" --session-id abc123

# 异步转存（适用于大文件）
npx polyv-live-cli@latest record convert -c 2588188 --file-name "直播回放" --session-id abc123 --async

# 转存并设为默认回放
npx polyv-live-cli@latest record convert -c 2588188 --file-name "直播回放" --session-id abc123 --set-as-default Y
```

**注意事项：**
- 同步模式会立即返回点播视频ID（vid）
- 异步模式适用于大文件转存，vid需要通过回调获取
- 同一账号5分钟内只能调用一次转存接口

---

### record set-default

设置默认回放视频。

```bash
npx polyv-live-cli@latest record set-default -c <频道ID> --video-id <视频ID> [选项]
```

**参数：**
- `-c, --channel-id <channelId>` - 频道ID（必填）
- `--video-id <videoId>` - 视频ID（必填）
- `--list-type <playback|vod>` - 列表类型
- `-o, --output <format>` - 输出格式

**示例：**

```bash
# 从回放列表设置默认视频
npx polyv-live-cli@latest record set-default -c 2588188 --video-id 73801f70c8 --list-type playback

# 从点播列表设置默认视频
npx polyv-live-cli@latest record set-default -c 2588188 --video-id 73801f70c8 --list-type vod
```

---

## 常见工作流程

### 直播后设置回放

```bash
# 1. 查询当前回放设置
npx polyv-live-cli@latest record setting get -c 2588188

# 2. 转存录制文件到点播
npx polyv-live-cli@latest record convert -c 2588188 --file-name "产品介绍直播" --session-id session123

# 3. 设置为默认回放视频
npx polyv-live-cli@latest record set-default -c 2588188 --video-id vid456 --list-type playback

# 4. 开启回放功能
npx polyv-live-cli@latest record setting set -c 2588188 --playback-enabled Y
```

### 批量转存历史直播

```bash
# 查询场次列表获取sessionId
npx polyv-live-cli@latest session list -c 2588188

# 依次转存各场次的录制文件
npx polyv-live-cli@latest record convert -c 2588188 --file-name "直播01" --session-id session1 --async
npx polyv-live-cli@latest record convert -c 2588188 --file-name "直播02" --session-id session2 --async
```

## 相关API文档

- [查询频道回放设置](https://help.polyv.net/#/live/api/channel/playback/get_playback_setting)
- [修改频道回放设置](https://help.polyv.net/#/live/api/channel/playback/set_record_setting)
- [录制文件转存点播](https://help.polyv.net/#/live/api/channel/playback/record_convert)
- [设置默认回放视频](https://help.polyv.net/#/live/api/channel/playback/set_record_default)
