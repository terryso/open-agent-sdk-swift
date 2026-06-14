# 卡片推送命令

管理直播间的卡片推送功能，在直播过程中向观众推送营销卡片。

## 概述

卡片推送功能允许运营人员在直播过程中向观众推送各种类型的营销卡片，如红包、礼品盒、二维码等，提升观众互动和转化率。

## 命令列表

### 列出卡片配置

```bash
npx polyv-live-cli@latest card-push list -c <频道ID>
npx polyv-live-cli@latest card-push list -c 3151318 -o json  # JSON格式输出
```

### 创建卡片配置

```bash
# 基本创建（手动推送）
npx polyv-live-cli@latest card-push create -c <频道ID> \
  --image-type <图片类型> \
  --title <卡片标题> \
  --link <跳转链接> \
  --duration <倒计时时长> \
  --show-condition PUSH

# 定时弹出（观看时长触发）
npx polyv-live-cli@latest card-push create -c 3151318 \
  --image-type giftbox \
  --title "限时优惠" \
  --link "https://example.com/promo" \
  --duration 10 \
  --show-condition WATCH \
  --condition-value 30 \
  --condition-unit SECONDS

# 完整参数示例
npx polyv-live-cli@latest card-push create -c 3151318 \
  --image-type redpack \
  --title "新年红包" \
  --link "https://example.com/redpack" \
  --duration 15 \
  --show-condition PUSH \
  --card-type qrCode \
  --enter-enabled Y \
  --link-enabled Y \
  --redirect-type tab \
  -o json
```

### 更新卡片配置

```bash
npx polyv-live-cli@latest card-push update -c <频道ID> --card-push-id <卡片ID> --title <新标题>
npx polyv-live-cli@latest card-push update -c 3151318 --card-push-id 123 --title "更新后的标题"
npx polyv-live-cli@latest card-push update -c 3151318 --card-push-id 123 --duration 20 --link "https://new-url.com"
```

### 推送卡片

```bash
npx polyv-live-cli@latest card-push push -c <频道ID> --card-push-id <卡片ID>
npx polyv-live-cli@latest card-push push -c 3151318 --card-push-id 123
```

### 取消推送

```bash
npx polyv-live-cli@latest card-push cancel -c <频道ID> --card-push-id <卡片ID>
npx polyv-live-cli@latest card-push cancel -c 3151318 --card-push-id 123
```

### 删除卡片配置

```bash
npx polyv-live-cli@latest card-push delete -c <频道ID> --card-push-id <卡片ID>
npx polyv-live-cli@latest card-push delete -c 3151318 --card-push-id 123
```

## 参数说明

### 通用参数

| 参数 | 说明 | 必填 |
|------|------|------|
| -c, --channel-id | 频道ID | 是 |
| -o, --output | 输出格式 (table/json) | 否 |

### 创建/更新参数

| 参数 | 说明 | 值 |
|------|------|------|
| --image-type | 卡片图片类型 | giftbox(礼盒), redpack(红包), custom(自定义) |
| --title | 卡片标题 | 字符串 |
| --link | 点击跳转链接 | URL |
| --duration | 卡片倒计时时长(秒) | 数字 |
| --show-condition | 弹出方式 | PUSH(手动推送), WATCH(观看时长触发) |
| --condition-value | 触发条件值 | 数字 |
| --condition-unit | 触发条件单位 | SECONDS(秒), MINUTES(分钟) |
| --card-type | 卡片类型 | common(普通), qrCode(二维码) |
| --enter-enabled | 是否允许进场推送 | Y/N |
| --link-enabled | 是否启用跳转 | Y/N |
| --redirect-type | 跳转方式 | tab(新标签页), window(新窗口), self(当前页) |
| --countdown-msg | 倒计时提示语 | 字符串 |
| --duration-position | 倒计时位置 | top/bottom |

## 卡片类型说明

### image-type 图片类型

- **giftbox**: 礼盒样式
- **redpack**: 红包样式
- **custom**: 自定义图片

### show-condition 弹出方式

- **PUSH**: 手动推送，需要调用 push 命令
- **WATCH**: 观看时长触发，需配合 condition-value 和 condition-unit

### card-type 卡片类型

- **common**: 普通卡片
- **qrCode**: 二维码卡片

## 典型工作流程

### 手动推送流程

```bash
# 1. 创建卡片配置
npx polyv-live-cli@latest card-push create -c 3151318 \
  --image-type giftbox \
  --title "限时优惠" \
  --link "https://shop.example.com/promo" \
  --duration 10 \
  --show-condition PUSH

# 2. 在适当时机推送卡片
npx polyv-live-cli@latest card-push push -c 3151318 --card-push-id 123

# 3. 如需取消推送
npx polyv-live-cli@latest card-push cancel -c 3151318 --card-push-id 123
```

### 自动弹出流程

```bash
# 创建观看30秒后自动弹出的卡片
npx polyv-live-cli@latest card-push create -c 3151318 \
  --image-type redpack \
  --title "新手红包" \
  --link "https://shop.example.com/redpack" \
  --duration 15 \
  --show-condition WATCH \
  --condition-value 30 \
  --condition-unit SECONDS
```

### 管理现有卡片

```bash
# 列出所有卡片
npx polyv-live-cli@latest card-push list -c 3151318

# 更新卡片标题
npx polyv-live-cli@latest card-push update -c 3151318 --card-push-id 123 --title "新标题"

# 删除不需要的卡片
npx polyv-live-cli@latest card-push delete -c 3151318 --card-push-id 123
```

## 输出示例

### list 命令输出

```
┌─────────┬────────────┬──────────┬──────────┬───────────────┐
│ 卡片ID  │ 标题       │ 图片类型 │ 倒计时   │ 弹出方式      │
├─────────┼────────────┼──────────┼──────────┼───────────────┤
│ 123     │ 限时优惠   │ giftbox  │ 10秒     │ 手动推送      │
│ 124     │ 新手红包   │ redpack  │ 15秒     │ 观看30秒触发  │
└─────────┴────────────┴──────────┴──────────┴───────────────┘
```

### create 命令输出

```
✓ 卡片配置创建成功

卡片ID: 125
标题: 新年特惠
图片类型: giftbox
弹出方式: 手动推送
```

## 注意事项

1. **推送时机**: 使用 PUSH 模式时，需确保直播正在进行中才能推送
2. **条件设置**: WATCH 模式下，condition-value 和 condition-unit 必须同时设置
3. **链接有效性**: 确保 link 参数指向有效的 URL
4. **倒计时**: duration 决定卡片在观众端显示的时长
