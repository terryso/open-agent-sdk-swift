# 优惠券管理

## 概述

优惠券是直播购物时可以使用的折扣码，用于促进销售和提高观众参与度。

## 创建优惠券

### 基本优惠券

```bash
npx polyv-live-cli@latest coupon create \
  -c 3151318 \
  -n "夏季特惠" \
  --discount 10.00
```

### 完整选项

```bash
npx polyv-live-cli@latest coupon create \
  -c 3151318 \
  -n "VIP折扣" \
  --discount 50.00 \
  --type percentage \
  --min-purchase 100.00 \
  --max-usage 1000 \
  --start-time "2024-06-01T00:00:00Z" \
  --end-time "2024-06-30T23:59:59Z"
```

### 优惠券选项

| 选项 | 说明 | 必填 |
|------|------|------|
| `-c, --channelId` | 频道ID | 是 |
| `-n, --name` | 优惠券名称 | 是 |
| `--discount` | 折扣金额/比例 | 是 |
| `--type` | `percentage`（百分比）或 `fixed`（固定金额） | 否（默认：fixed） |
| `--min-purchase` | 最低消费金额 | 否 |
| `--max-usage` | 最大使用次数 | 否 |
| `--start-time` | 生效时间（ISO 8601格式） | 否 |
| `--end-time` | 失效时间（ISO 8601格式） | 否 |

### 折扣类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `fixed` | 固定金额减免 | 减¥10.00 |
| `percentage` | 百分比折扣 | 打9折 |

## 优惠券列表

```bash
# 基本列表
npx polyv-live-cli@latest coupon list -c 3151318

# 输出：
# 优惠券ID | 名称 | 折扣 | 类型 | 使用情况 | 状态
# cpn001   | 夏季特惠 | ¥10.00 | fixed | 50/100 | 有效
# cpn002   | VIP9折 | 10% | percentage | 25/- | 有效
```

### JSON输出

```bash
npx polyv-live-cli@latest coupon list -c 3151318 -o json
```

## 获取优惠券详情

```bash
# 表格格式
npx polyv-live-cli@latest coupon get -c 3151318 --couponId cpn001

# JSON格式
npx polyv-live-cli@latest coupon get -c 3151318 --couponId cpn001 -o json
```

## 删除优惠券

```bash
# 带确认提示
npx polyv-live-cli@latest coupon delete -c 3151318 --couponId cpn001

# 强制删除
npx polyv-live-cli@latest coupon delete -c 3151318 --couponId cpn001 -f
```

## 常用工作流程

### 创建限时特卖优惠券

```bash
# 创建限时优惠券
npx polyv-live-cli@latest coupon create \
  -c 3151318 \
  -n "限时8折" \
  --discount 20 \
  --type percentage \
  --max-usage 500 \
  --start-time "2024-06-15T10:00:00Z" \
  --end-time "2024-06-15T12:00:00Z"
```

### 创建VIP专属优惠券

```bash
# 高价值VIP优惠券
npx polyv-live-cli@latest coupon create \
  -c 3151318 \
  -n "VIP专属立减50" \
  --discount 50.00 \
  --type fixed \
  --min-purchase 200.00 \
  --max-usage 100
```

### 查看有效优惠券

```bash
# 获取所有优惠券并筛选有效
npx polyv-live-cli@latest coupon list -c 3151318 -o json | jq '.data[] | select(.status == "active")'
```

### 批量创建优惠券

```bash
# 为营销活动创建多张优惠券
for i in {1..10}; do
  npx polyv-live-cli@latest coupon create \
    -c 3151318 \
    -n "活动优惠券$i" \
    --discount 10.00 \
    --max-usage 100
done
```

## 优惠券状态

| 状态 | 说明 |
|------|------|
| `active` | 优惠券可使用 |
| `expired` | 优惠券已过期 |
| `exhausted` | 已达最大使用次数 |
| `disabled` | 已手动禁用 |

## 故障排除

### "Coupon not found"（优惠券不存在）

- 确认优惠券ID是否正确
- 检查优惠券是否属于该频道

### "Coupon expired"（优惠券已过期）

- 检查结束时间：`npx polyv-live-cli@latest coupon get -c <频道ID> --couponId <优惠券ID>`
- 创建新的优惠券并设置有效日期

### "Maximum usage reached"（已达最大使用次数）

- 检查使用次数：`npx polyv-live-cli@latest coupon get -c <频道ID> --couponId <优惠券ID>`
- 创建新优惠券或增加使用上限

### "Minimum purchase not met"（未达到最低消费）

- 告知用户最低消费要求
- 最低消费在创建优惠券时设置
