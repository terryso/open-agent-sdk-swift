# 频道管理

## 概述

频道是保利威直播的核心资源。每个频道代表一个直播间，拥有独立的配置、商品和回放设置。

## 频道增删改查

### 创建频道

```bash
# 基本创建
npx polyv-live-cli@latest channel create -n "我的直播"

# 带描述
npx polyv-live-cli@latest channel create -n "产品演示" -d "新产品功能演示"

# 完整选项
npx polyv-live-cli@latest channel create \
  -n "高级网络研讨会" \
  -d "月度付费用户专属研讨会" \
  --scene topclass \
  --template ppt \
  --password web123 \
  --max-viewers 1000 \
  --auto-record

# JSON输出（便于程序化处理）
npx polyv-live-cli@latest channel create -n "API频道" -o json
```

### 场景类型 (newScene)

| 场景 | 说明 | 备注 |
|------|------|------|
| `topclass` | 大班课（默认） | ✅ 推荐 |
| `alone` | 活动营销 | ✅ |
| `seminar` | 研讨会 | ✅ |
| `train` | 企业培训 | ✅ |
| `double` | 双师课 | ⚠️ 需开通权限 |
| `guide` | 导播 | ⚠️ 需开通权限 |

### 模板类型 (template)

| 模板 | 说明 |
|------|------|
| `ppt` | 三分屏-横屏（默认） |
| `portrait_ppt` | 三分屏-竖屏 |
| `alone` | 纯视频-横屏 |
| `portrait_alone` | 纯视频-竖屏 |
| `topclass` | 纯视频极速-横屏 |
| `portrait_topclass` | 纯视频极速-竖屏 |
| `seminar` | 研讨会 |

### 查看频道列表

```bash
# 基本列表（第一页，20条）
npx polyv-live-cli@latest channel list

# 分页查询
npx polyv-live-cli@latest channel list -P 2 -l 10

# 按关键词筛选
npx polyv-live-cli@latest channel list --keyword "研讨会"

# 按分类筛选
npx polyv-live-cli@latest channel list --category-id "cat123"

# JSON输出
npx polyv-live-cli@latest channel list -o json
```

### 查看频道详情

```bash
# 表格格式
npx polyv-live-cli@latest channel get -c 3151318

# JSON格式
npx polyv-live-cli@latest channel get -c 3151318 -o json
```

### 更新频道

```bash
# 更新名称
npx polyv-live-cli@latest channel update -c 3151318 -n "新名称"

# 更新描述
npx polyv-live-cli@latest channel update -c 3151318 -d "更新后的描述"

# 更新密码
npx polyv-live-cli@latest channel update -c 3151318 -p "newpass123"

# 更新多个字段
npx polyv-live-cli@latest channel update \
  -c 3151318 \
  -n "重命名频道" \
  --max-viewers 5000 \
  --publisher "主持人姓名"
```

### 删除频道

```bash
# 带确认提示
npx polyv-live-cli@latest channel delete -c 3151318

# 强制删除（无确认）
npx polyv-live-cli@latest channel delete -c 3151318 -f

# JSON输出
npx polyv-live-cli@latest channel delete -c 3151318 -o json
```

### 批量删除

```bash
# 删除多个频道
npx polyv-live-cli@latest channel batch-delete --channelIds 3151318 3151319 3151320

# 强制批量删除
npx polyv-live-cli@latest channel batch-delete --channelIds 3151318 3151319 -f
```

## 频道配置

### 密码保护

```bash
# 创建时设置密码
npx polyv-live-cli@latest channel create -n "私密直播" -p "secure123"

# 更新密码
npx polyv-live-cli@latest channel update -c 3151318 -p "newpass456"

# 移除密码（设置为空）
npx polyv-live-cli@latest channel update -c 3151318 -p ""
```

### 观众人数限制

```bash
# 设置最大观看人数
npx polyv-live-cli@latest channel create -n "限定直播" --max-viewers 500

# 更新人数限制
npx polyv-live-cli@latest channel update -c 3151318 --max-viewers 1000
```

### 自动录制

```bash
# 启用自动录制
npx polyv-live-cli@latest channel create -n "录制直播" --auto-record
```

### 封面和引导图

```bash
# 更新封面图
npx polyv-live-cli@latest channel update -c 3151318 --cover-img "https://example.com/cover.jpg"

# 更新引导图
npx polyv-live-cli@latest channel update -c 3151318 --splash-img "https://example.com/splash.jpg"
```

## 输出格式

### 表格格式（默认）

```bash
npx polyv-live-cli@latest channel list
# 显示表格，包含以下列：
# 频道ID | 名称 | 状态 | 场景 | 创建时间
```

### JSON格式

```bash
npx polyv-live-cli@latest channel list -o json

# 返回：
# {
#   "code": 200,
#   "status": "success",
#   "data": {
#     "contents": [...],
#     "pageSize": 20,
#     "pageNumber": 1,
#     "totalItems": 50
#   }
# }
```

## 常用工作流程

### 创建网络研讨会频道

```bash
npx polyv-live-cli@latest channel create \
  -n "Q4战略研讨会" \
  -d "全员季度战略回顾" \
  --scene seminar \
  --template seminar \
  --max-viewers 500 \
  --auto-record \
  -o json
```

### 创建电商直播频道

```bash
npx polyv-live-cli@latest channel create \
  -n "限时特卖活动" \
  -d "24小时限时特卖直播" \
  --scene alone \
  --template portrait_alone \
  --max-viewers 10000 \
  -o json
```

### 批量清理测试频道

```bash
# 列出测试频道
npx polyv-live-cli@latest channel list --keyword "test" -o json | jq '.data.contents[].channelId'

# 批量删除
npx polyv-live-cli@latest channel batch-delete --channelIds 123 456 789 -f
```

## 故障排除

### "Channel not found"（频道不存在）

- 确认频道ID是否正确
- 检查频道是否属于当前账号
- 确认频道是否已被删除

### "Invalid scene type"（无效场景类型）

- 使用以下之一：`topclass`、`alone`、`seminar`、`train`、`double`、`guide`
- 场景名称区分大小写
- `double` 和 `guide` 需要开通权限

### "密码必须是6-16位字母数字"

- 只使用字母和数字
- 长度必须在6-16个字符之间
