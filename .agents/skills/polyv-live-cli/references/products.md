# 商品管理

## 概述

商品是直播过程中可以展示和销售的项目。每个频道可以关联多个商品。

## 商品列表

### 基本列表

```bash
npx polyv-live-cli@latest product list -c 3151318

# 输出：
# 商品ID | 名称 | 价格 | 库存 | 状态
# prod001 | 商品A | ¥99.00 | 100 | 上架
# prod002 | 商品B | ¥199.00 | 50 | 上架
```

### JSON输出

```bash
npx polyv-live-cli@latest product list -c 3151318 -o json
```

## 添加商品

### 基本商品

```bash
npx polyv-live-cli@latest product add \
  -c 3151318 \
  --name "高级产品" \
  --price 99.00
```

### 完整选项

```bash
npx polyv-live-cli@latest product add \
  -c 3151318 \
  --name "豪华套餐" \
  --price 299.00 \
  --stock 100 \
  --description "高级豪华套餐，包含额外配件" \
  --image "https://example.com/product.jpg"
```

### 商品选项

| 选项 | 说明 | 必填 |
|------|------|------|
| `-c, --channelId` | 频道ID | 是 |
| `--name` | 商品名称 | 是 |
| `--price` | 商品价格 | 是 |
| `--stock` | 库存数量 | 否 |
| `--description` | 商品描述 | 否 |
| `--image` | 商品图片URL | 否 |

## 获取商品详情

```bash
# 表格格式
npx polyv-live-cli@latest product get -c 3151318 -p prod001

# JSON格式
npx polyv-live-cli@latest product get -c 3151318 -p prod001 -o json
```

## 更新商品

```bash
# 更新价格
npx polyv-live-cli@latest product update -c 3151318 -p prod001 --price 129.00

# 更新库存
npx polyv-live-cli@latest product update -c 3151318 -p prod001 --stock 200

# 更新名称和描述
npx polyv-live-cli@latest product update \
  -c 3151318 \
  -p prod001 \
  --name "更新后的商品名称" \
  --description "新描述"

# 更新图片
npx polyv-live-cli@latest product update -c 3151318 -p prod001 --image "https://example.com/new-image.jpg"
```

## 删除商品

```bash
# 带确认提示
npx polyv-live-cli@latest product delete -c 3151318 -p prod001

# 强制删除
npx polyv-live-cli@latest product delete -c 3151318 -p prod001 -f
```

## 常用工作流程

### 为直播特卖设置商品

```bash
# 创建频道
npx polyv-live-cli@latest channel create -n "限时特卖" -o json

# 添加商品
npx polyv-live-cli@latest product add -c 3151318 --name "特卖商品1" --price 49.00 --stock 50
npx polyv-live-cli@latest product add -c 3151318 --name "特卖商品2" --price 99.00 --stock 30
npx polyv-live-cli@latest product add -c 3151318 --name "特卖商品3" --price 149.00 --stock 20

# 验证商品
npx polyv-live-cli@latest product list -c 3151318
```

### 批量更新价格

```bash
# 以JSON格式导出商品列表
npx polyv-live-cli@latest product list -c 3151318 -o json > products.json

# 编程方式编辑价格
# ... 更新 products.json ...

# 应用更新
for id in $(cat products.json | jq -r '.data[].productId'); do
  new_price=$(cat products.json | jq -r ".data[] | select(.productId == \"$id\") | .price")
  npx polyv-live-cli@latest product update -c 3151318 -p "$id" --price "$new_price"
done
```

### 库存管理

```bash
# 检查库存水平
npx polyv-live-cli@latest product list -c 3151318 -o json | jq '.data[] | {name: .name, stock: .stock}'

# 销售后更新库存
npx polyv-live-cli@latest product update -c 3151318 -p prod001 --stock 45
```

## 商品状态

| 状态 | 说明 |
|------|------|
| `active` | 商品可见且可购买 |
| `inactive` | 商品已隐藏 |
| `out_of_stock` | 库存不足 |

## 故障排除

### "Product not found"（商品不存在）

- 确认商品ID是否正确
- 确保商品属于指定频道

### "Insufficient stock"（库存不足）

- 检查当前库存：`npx polyv-live-cli@latest product get -c <频道ID> -p <商品ID>`
- 更新库存：`npx polyv-live-cli@latest product update -c <频道ID> -p <商品ID> --stock <数量>`

### "Invalid price format"（价格格式无效）

- 使用小数格式：`99.00` 而非 `99`
- 价格必须为正数
