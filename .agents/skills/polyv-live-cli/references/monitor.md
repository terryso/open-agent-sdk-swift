# 直播监控

## 概述

监控命令提供直播实时监控面板，用于查看直播状态、观众数据和推流质量。

## 启动监控面板

```bash
# 启动默认监控面板
npx polyv-live-cli@latest monitor

# 设置刷新间隔（秒）
npx polyv-live-cli@latest monitor -r 3

# 使用紧凑布局
npx polyv-live-cli@latest monitor -l compact

# 使用暗色主题
npx polyv-live-cli@latest monitor -t dark

# 使用配置文件
npx polyv-live-cli@latest monitor -c ./monitor-config.json
```

### 监控选项

| 选项 | 说明 | 可选值 |
|------|------|--------|
| `-r, --refresh` | 刷新间隔（秒） | 默认5秒 |
| `-l, --layout` | 面板布局 | default, compact, single |
| `-t, --theme` | 颜色主题 | default, dark |
| `-c, --config` | 配置文件路径 | - |
| `-o, --output` | 输出格式 | table（默认）/ json |
| `-v, --verbose` | 详细日志 | 标志 |
| `-d, --debug` | 调试模式 | 标志 |

## 查看监控状态

```bash
# 查看当前监控状态
npx polyv-live-cli@latest monitor status

# JSON输出
npx polyv-live-cli@latest monitor status -o json
```

## 管理配置

### 查看当前配置

```bash
npx polyv-live-cli@latest monitor config

# JSON输出
npx polyv-live-cli@latest monitor config -o json
```

### 导出配置

```bash
# 导出配置到文件
npx polyv-live-cli@latest monitor export ./my-monitor-config.json
```

### 导入配置

```bash
# 从文件导入配置
npx polyv-live-cli@latest monitor import ./my-monitor-config.json
```

## 列出可用选项

### 可用布局

```bash
npx polyv-live-cli@latest monitor layouts

# 输出：
# ┌───────────┬────────────────────────────┐
# │ Layout    │ Description                │
# ├───────────┼────────────────────────────┤
# │ default   │ 标准布局，显示所有面板     │
# │ compact   │ 紧凑布局，适合小屏幕       │
# │ single    │ 单面板布局，专注单一指标   │
# └───────────┴────────────────────────────┘
```

### 可用主题

```bash
npx polyv-live-cli@latest monitor themes

# 输出：
# ┌───────────┬────────────────────────────┐
# │ Theme     │ Description                │
# ├───────────┼────────────────────────────┤
# │ default   │ 浅色主题                   │
# │ dark      │ 暗色主题                   │
# └───────────┴────────────────────────────┘
```

## 兼容性测试

```bash
# 测试终端兼容性
npx polyv-live-cli@latest monitor test

# 输出包含：
# ✅ 终端尺寸: 120x30
# ✅ 颜色支持: 256色
# ✅ Unicode支持: 是
```

## 配置文件格式

配置文件使用JSON格式：

```json
{
  "refreshInterval": 5,
  "layout": "default",
  "theme": "dark",
  "panels": [
    "stream",
    "viewers",
    "engagement"
  ],
  "alerts": {
    "enabled": true,
    "lowBitrate": 500,
    "highLatency": 3000,
    "viewerDrop": 10
  }
}
```

### 配置字段说明

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `refreshInterval` | 刷新间隔（秒） | 5 |
| `layout` | 面板布局 | default |
| `theme` | 颜色主题 | default |
| `panels` | 显示的面板 | 全部 |
| `alerts.enabled` | 启用告警 | true |
| `alerts.lowBitrate` | 低码率告警阈值（kbps） | 500 |
| `alerts.highLatency` | 高延迟告警阈值（ms） | 3000 |
| `alerts.viewerDrop` | 观众下降告警阈值（%） | 10 |

## 常用工作流程

### 启动直播监控

```bash
# 1. 启动频道直播
npx polyv-live-cli@latest stream start -c 3151318

# 2. 在另一个终端启动监控
npx polyv-live-cli@latest monitor -r 3 -t dark
```

### 配置监控告警

```bash
# 1. 创建配置文件
cat > monitor-alerts.json << 'EOF'
{
  "refreshInterval": 3,
  "layout": "compact",
  "alerts": {
    "enabled": true,
    "lowBitrate": 800,
    "highLatency": 2000,
    "viewerDrop": 5
  }
}
EOF

# 2. 使用配置启动监控
npx polyv-live-cli@latest monitor -c monitor-alerts.json
```

### 保存和恢复配置

```bash
# 导出当前配置
npx polyv-live-cli@latest monitor export ./saved-config.json

# 之后恢复配置
npx polyv-live-cli@latest monitor import ./saved-config.json
```

## 面板布局说明

### default（默认布局）

```
┌─────────────────────────────────────────────────────────┐
│ 直播状态面板                              │
├─────────────────────────────────────────────────────────┤
│ 观众数据面板                              │
├─────────────────────────────────────────────────────────┤
│ 互动统计面板                           │
└─────────────────────────────────────────────────────────┘
```

### compact（紧凑布局）

```
┌────────────────────┬────────────────────┐
│ Stream             │ Viewers            │
├────────────────────┴────────────────────┤
│ Engagement                               │
└─────────────────────────────────────────┘
```

### single（单面板布局）

```
┌─────────────────────────────────────────┐
│                                         │
│         Stream Status Panel             │
│                                         │
└─────────────────────────────────────────┘
```

## 故障排除

### "终端不支持"

- 确保终端支持ANSI颜色
- 尝试使用 `monitor test` 检测兼容性
- 使用不支持Unicode的终端时，部分图标可能显示异常

### "刷新间隔过快"

- 最小刷新间隔为1秒
- 建议使用3-5秒间隔以避免API限流
- 网络较慢时可增加刷新间隔

### "配置文件加载失败"

- 检查JSON格式是否正确
- 确保文件路径存在
- 使用 `monitor config` 查看当前配置验证格式
