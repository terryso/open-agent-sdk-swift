# 转播管理命令

批量创建和管理转播频道，## 如述

转播功能允许将主直播内容同时分发到多个频道，## 命令

### 创建转播频道

```bash
# 批量创建转播频道
npx polyv-live-cli@latest transmit create -c <主频道ID> --names "频道1,频道2,频道3"

# 礼例
npx polyv-live-cli@latest transmit create -c 3151318 --names "转播频道1,转播频道2,转播频道3"

# JSON格式输出
npx polyv-live-cli@latest transmit create -c 3151318 --names "频道1,频道2" -o json
```

**参数说明**:

| 参数 | 必填 | 说明 |
|------|------|------|
| -c, --channelId | 是 | 主频道ID（发起转播的频道） |
| --names | 是 | 转播频道名称，多个名称用逗号分隔，最多支持100个 |

### 列出转播关联

```bash
# 列出转播关联
npx polyv-live-cli@latest transmit list -c <频道ID>

# JSON格式输出
npx polyv-live-cli@latest transmit list -c 3151318 -o json
```

**参数说明**:

| 参数 | 必填 | 说明 |
|------|------|------|
| -c, --channelId | 是 | 频道ID |

### 输出格式

所有命令支持 `-o table`（默认）表格格式）或 `-o json`（JSON格式，## 选项

| 选项 | 缩写 | 说明 |
|------|------|------|
| -o | --output | 格式 | table 或 json |

## 限制

- 诏次最多创建 **100** 个转播频道
- 转播频道名称不能包含逗号（会被自动分割）
- 输出格式仅支持 table 和 json

## 使用示例

### 场景：批量创建多个转播频道

```bash
# 为频道 3151318 创建3个转播频道
npx polyv-live-cli@latest transmit create -c 3151318 --names "北京分会场上海分会场,广州分会场

# JSON格式输出（便于程序化处理）
npx polyv-live-cli@latest transmit create -c 3151318 --names "北京分会场,上海分会场" -o json
```

### 场景：查看转播关联

```bash
# 查看频道 3151318 的转播关联
npx polyv-live-cli@latest transmit list -c 3151318

# JSON格式输出
npx polyv-live-cli@latest transmit list -c 3151318 -o json
```

## 相关API

- [批量创建转播频道](https://help.polyv.net/#/live/api/channel/transmit/batch_create)
- [获取转播关联](https://help.polyv.net/#/live/api/channel/transmit/get_associations)
