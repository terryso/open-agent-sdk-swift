# 场景初始化

## 概述

场景初始化命令用于快速创建预配置的频道，适用于电商、教育、活动等常见场景。

## 查看可用场景

```bash
npx polyv-live-cli@latest setup --list

# 输出：
# 场景        | 描述
# e-commerce  | 电商直播（预置商品功能）
# education   | 在线教育/云课堂
# event       | 活动/会议直播
# webinar     | 专业网络研讨会
```

## 电商场景

适用于直播带货和电商直播。

```bash
npx polyv-live-cli@latest setup e-commerce

# 创建内容：
# - 电商模板频道
# - 开启频道商品库
# - 示例商品
# - 新人优惠券
# - 开启观看页优惠券展示
# - 购物车集成
# - 商品展示布局
```

### 电商场景选项

```bash
npx polyv-live-cli@latest setup e-commerce \
  --channel-name "限时特卖" \
  --products 10 \
  --coupons 5
```

## 教育场景

适用于在线课程和培训。

```bash
npx polyv-live-cli@latest setup education

# 创建内容：
# - 云课堂模板频道
# - PPT/文档支持
# - 学员互动功能
# - 自动录制
```

### 教育场景选项

```bash
npx polyv-live-cli@latest setup education \
  --channel-name "在线课程" \
  --max-students 500 \
  --auto-record
```

## 活动场景

适用于活动和会议直播。

```bash
npx polyv-live-cli@latest setup event

# 创建内容：
# - 高容量频道
# - 多机位支持
# - 互动问答功能
# - 社交分享
```

### 活动场景选项

```bash
npx polyv-live-cli@latest setup event \
  --channel-name "年度大会" \
  --max-viewers 10000 \
  --live-qa \
  --social-sharing
```

## 研讨会场景

适用于专业网络研讨会。

```bash
npx polyv-live-cli@latest setup webinar

# 创建内容：
# - 专业研讨会频道
# - 报名系统
# - 投票问卷
# - 录制和回放
```

### 研讨会场景选项

```bash
npx polyv-live-cli@latest setup webinar \
  --channel-name "产品演示" \
  --registration \
  --polls \
  --auto-record
```

## 自定义配置

```bash
# 自定义配置
npx polyv-live-cli@latest setup custom \
  --channel-name "自定义直播" \
  --scene topclass \
  --template ppt \
  --products \
  --coupons \
  --auto-record
```

## 常用工作流程

### 快速电商配置

```bash
# 一键完成电商配置
npx polyv-live-cli@latest setup e-commerce \
  --channel-name "今日特惠" \
  --products 20 \
  --coupons 3 \
  -o json
```

### 教育课程配置

```bash
# 创建课程频道
npx polyv-live-cli@latest setup education \
  --channel-name "JavaScript基础" \
  --max-students 200 \
  --auto-record

# 添加课程资料（如支持）
npx polyv-live-cli@latest document upload -c 3151318 -f slides.pdf
```

### 多日活动

```bash
# 创建活动频道
npx polyv-live-cli@latest setup event \
  --channel-name "技术峰会2024" \
  --max-viewers 5000 \
  --live-qa

# 活动会有多场直播
# 每场直播创建一个新回放
```

## 场景选项汇总

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--channel-name` | 新频道名称 | 基于场景 |
| `--products` | 示例商品数量 | 0 |
| `--coupons` | 示例优惠券数量 | 0 |
| `--max-viewers` | 最大并发观众数 | 基于场景 |
| `--auto-record` | 启用自动录制 | false |
| `--registration` | 启用报名 | false |
| `--live-qa` | 启用互动问答 | false |
| `--polls` | 启用投票 | false |
| `-o, --output` | 输出格式 | table |

## 初始化后操作

运行场景初始化后：

1. **获取推流凭证**
   ```bash
   npx polyv-live-cli@latest stream get-key -c <频道ID>
   ```

2. **配置商品**（如适用）
   ```bash
   npx polyv-live-cli@latest product list -c <频道ID>
   npx polyv-live-cli@latest product update -c <频道ID> -p <商品ID> --price <价格>
   ```

3. **配置优惠券**（如适用）
   ```bash
   npx polyv-live-cli@latest coupon list -c <频道ID>
   ```

4. **开始直播**
   ```bash
   npx polyv-live-cli@latest stream start -c <频道ID>
   ```

## 故障排除

### "Scene template not found"（场景模板不存在）

- 使用 `--list` 查看可用场景
- 场景名称区分大小写

### "Setup failed"（初始化失败）

- 检查认证是否有效
- 确认账号有权限
- 尝试使用 --verbose 查看详细信息

### "Products not created"（商品未创建）

- 某些场景默认不包含商品
- 使用 `--products <数量>` 指定商品数量
