# 文档管理

管理直播频道的课件文档，支持上传、查看和删除文档。

## 命令概览

| 命令 | 说明 |
|------|------|
| `document list` | 获取频道文档列表 |
| `document upload` | 上传文档（通过URL） |
| `document delete` | 删除文档 |
| `document status` | 查询文档转码状态 |

## document list

获取指定频道的课件文档列表。

### 语法

```bash
npx polyv-live-cli@latest document list -c <频道ID> [选项]
```

### 选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--channel-id <ID>` | `-c` | 频道ID（必填） | - |
| `--status <状态>` | `-s` | 文档状态过滤 | - |
| `--page <页码>` | `-P` | 页码 | 1 |
| `--page-size <数量>` | `-l` | 每页数量 | 10 |
| `--output <格式>` | `-o` | 输出格式 (table/json) | table |

### 文档状态

| 状态值 | 说明 |
|--------|------|
| `normal` | 正常 |
| `waitUpload` | 等待上传 |
| `failUpload` | 上传失败 |
| `waitConvert` | 等待转码 |
| `failConvert` | 转码失败 |

### 示例

```bash
# 列出频道所有文档
npx polyv-live-cli@latest document list -c 3151318

# 过滤转码失败的文档
npx polyv-live-cli@latest document list -c 3151318 --status failConvert

# 分页查询
npx polyv-live-cli@latest document list -c 3151318 --page 2 --page-size 20

# JSON格式输出
npx polyv-live-cli@latest document list -c 3151318 -o json
```

## document upload

通过URL上传文档到频道。

### 语法

```bash
npx polyv-live-cli@latest document upload -c <频道ID> --url <文件URL> [选项]
```

### 选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--channel-id <ID>` | `-c` | 频道ID（必填） | - |
| `--url <URL>` | `-u` | 文件URL（必填） | - |
| `--type <类型>` | `-t` | 转换类型 | common |
| `--doc-name <名称>` | `-n` | 文档名称 | - |
| `--callback-url <URL>` | | 回调地址 | - |
| `--output <格式>` | `-o` | 输出格式 (table/json) | table |

### 转换类型

| 类型 | 说明 |
|------|------|
| `common` | 普通转换（静态PPT） |
| `animate` | 动效转换（保留PPT动画） |

### 支持格式

PPT、PDF、PPTX、DOC、DOCX、WPS

### 示例

```bash
# 上传PPT文档
npx polyv-live-cli@latest document upload -c 3151318 --url https://example.com/slides.pptx

# 上传带动画的PPT
npx polyv-live-cli@latest document upload -c 3151318 --url https://example.com/slides.pptx --type animate

# 指定文档名称
npx polyv-live-cli@latest document upload -c 3151318 --url https://example.com/slides.pptx --doc-name "产品介绍"

# 设置转码完成回调
npx polyv-live-cli@latest document upload -c 3151318 --url https://example.com/slides.pptx --callback-url https://myserver.com/callback
```

## document delete

删除指定文档。

### 语法

```bash
npx polyv-live-cli@latest document delete -c <频道ID> --file-id <文档ID> [选项]
```

### 选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--channel-id <ID>` | `-c` | 频道ID（必填） | - |
| `--file-id <ID>` | `-f` | 文档ID（必填） | - |
| `--type <类型>` | `-t` | 文档类型 | 自动检测 |
| `--force` | | 跳过确认提示 | false |
| `--output <格式>` | `-o` | 输出格式 (table/json) | table |

### 文档类型

| 类型 | 说明 |
|------|------|
| `old` | 旧版文档 |
| `new` | 新版文档 |

> 注意：如果不指定 `--type`，系统会自动检测文档类型。

### 示例

```bash
# 删除文档（会有确认提示）
npx polyv-live-cli@latest document delete -c 3151318 --file-id abc123

# 强制删除，跳过确认
npx polyv-live-cli@latest document delete -c 3151318 --file-id abc123 --force

# 指定文档类型
npx polyv-live-cli@latest document delete -c 3151318 --file-id abc123 --type new
```

## document status

查询文档转码状态。

### 语法

```bash
npx polyv-live-cli@latest document status -c <频道ID> --file-id <文档ID>
```

### 选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--channel-id <ID>` | `-c` | 频道ID（必填） | - |
| `--file-id <ID>` | `-f` | 文档ID（必填） | - |
| `--output <格式>` | `-o` | 输出格式 (table/json) | table |

### 示例

```bash
# 查询单个文档状态
npx polyv-live-cli@latest document status -c 3151318 --file-id abc123

# 批量查询（用逗号分隔）
npx polyv-live-cli@latest document status -c 3151318 --file-id abc123,def456

# JSON格式输出
npx polyv-live-cli@latest document status -c 3151318 --file-id abc123 -o json
```

## 输出示例

### document list 表格输出

```
┌──────────┬────────────────┬──────────┬────────┬─────────────┐
│ 文档ID   │ 文档名称       │ 类型     │ 状态   │ 创建时间    │
├──────────┼────────────────┼──────────┼────────┼─────────────┤
│ abc123   │ 产品介绍.pptx  │ pptx     │ normal │ 2024-03-20  │
│ def456   │ 公司简介.pdf   │ pdf      │ normal │ 2024-03-19  │
└──────────┴────────────────┴──────────┴────────┴─────────────┘
```

### document upload 输出

```
✓ 文档上传成功

文档ID: abc123
状态: waitConvert
类型: common
```

### document status 输出

```
┌──────────┬─────────────┬──────┬──────────┐
│ 文档ID   │ 转码状态    │ 类型 │ 总页数   │
├──────────┼─────────────┼──────┼──────────┤
│ abc123   │ success     │ new  │ 15       │
└──────────┴─────────────┴──────┴──────────┘
```

## 常见工作流程

### 上传并在直播中使用文档

```bash
# 1. 上传文档
npx polyv-live-cli@latest document upload -c 3151318 --url https://example.com/slides.pptx --type animate

# 2. 查看转码状态
npx polyv-live-cli@latest document status -c 3151318 --file-id <返回的文档ID>

# 3. 确认文档已就绪（状态为 success）
# 文档已可在直播间使用
```

### 批量管理文档

```bash
# 1. 查看所有转码失败的文档
npx polyv-live-cli@latest document list -c 3151318 --status failConvert -o json > failed.json

# 2. 逐个删除失败的文档
# jq -r '.contents[].fileId' failed.json | xargs -I {} npx polyv-live-cli@latest document delete -c 3151318 --file-id {} --force
```
