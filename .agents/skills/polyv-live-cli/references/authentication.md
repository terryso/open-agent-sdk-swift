# 身份认证配置

## 认证优先级

保利威直播 CLI 支持多种认证来源，按以下优先级顺序使用：

1. **命令行参数**：`--appId`、`--appSecret`、`--userId`
2. **会话账号**：`npx polyv-live-cli@latest use <账号名称>`
3. **账号标志**：`-a <名称>` 或 `--account <名称>`
4. **环境变量**：`POLYV_APP_ID`、`POLYV_APP_SECRET`、`POLYV_USER_ID`
5. **默认账号**：通过 `account set-default` 设置
6. **全局配置**：存储在 `~/.npx polyv-live-cli@latest/` 目录

## 账号管理

### 添加新账号

```bash
# 基本账号
npx polyv-live-cli@latest account add production \
  --app-id your-app-id \
  --app-secret your-app-secret

# 包含用户ID
npx polyv-live-cli@latest account add production \
  --app-id your-app-id \
  --app-secret your-app-secret \
  --user-id your-user-id
```

### 查看所有账号

```bash
npx polyv-live-cli@latest account list

# 输出示例：
# NAME         APP ID       DEFAULT
# production   abc123...    Yes
# staging      def456...    No
```

### 设置默认账号

```bash
npx polyv-live-cli@latest account set-default production
```

### 切换会话账号

```bash
# 切换当前会话使用的账号
npx polyv-live-cli@latest use staging

# 后续所有命令都会使用 staging 账号
npx polyv-live-cli@latest channel list
```

### 删除账号

```bash
npx polyv-live-cli@latest account delete old-account
```

## 使用内联凭证

### 单次命令指定凭证

```bash
# 直接使用凭证参数
npx polyv-live-cli@latest channel list --appId <id> --appSecret <secret>

# 使用账号标志简写
npx polyv-live-cli@latest channel list -a production

# 使用 --verbose 查看认证来源
npx polyv-live-cli@latest channel list --verbose
```

## 环境变量

### 在 Shell 配置文件中设置

```bash
# 添加到 ~/.bashrc、~/.zshrc 或 ~/.profile
export POLYV_APP_ID="your-app-id"
export POLYV_APP_SECRET="your-app-secret"
export POLYV_USER_ID="your-user-id"
```

### 在脚本中使用

```bash
#!/bin/bash
export POLYV_APP_ID="${APP_ID}"
export POLYV_APP_SECRET="${APP_SECRET}"

npx polyv-live-cli@latest channel list
```

## 验证认证状态

### 检查认证信息

```bash
# 使用 --verbose 输出显示认证来源
npx polyv-live-cli@latest channel list --verbose

# 输出包含：
# 🔐 认证来源: session-account
# 👤 账号: production
```

### 诊断认证问题

```bash
# 列出账号以验证配置
npx polyv-live-cli@latest account list

# 检查是否设置了默认账号
npx polyv-live-cli@latest account list | grep -i default
```

## 安全最佳实践

### 建议

- 日常使用账号管理功能
- CI/CD 流水线中使用环境变量
- 不同环境使用不同账号
- 定期轮换凭证

### 不建议

- 不要将凭证提交到版本控制
- 不要在团队成员之间共享账号
- 不要在开发环境使用生产凭证

## CI/CD 集成

### GitHub Actions

```yaml
env:
  POLYV_APP_ID: ${{ secrets.POLYV_APP_ID }}
  POLYV_APP_SECRET: ${{ secrets.POLYV_APP_SECRET }}

steps:
  - name: 列出频道
    run: npx polyv-live-cli@latest channel list
```

### GitLab CI

```yaml
variables:
  POLYV_APP_ID: ${POLYV_APP_ID}
  POLYV_APP_SECRET: ${POLYV_APP_SECRET}

script:
  - npx polyv-live-cli@latest channel list
```

## 故障排除

### "Auth configuration is incomplete"（认证配置不完整）

此错误表示未找到有效凭证：

1. 检查账号是否存在：`npx polyv-live-cli@latest account list`
2. 设置默认账号：`npx polyv-live-cli@latest account set-default <名称>`
3. 或使用内联凭证：`npx polyv-live-cli@latest channel list -a <名称>`

### "Invalid credentials"（无效凭证）

1. 验证 appId 和 appSecret 是否正确
2. 检查凭证是否已过期
3. 确保账号具有必要权限

### 如何获取保利威凭证

1. 登录 [保利威后台](https://www.polyv.net/)
2. 进入「开发设置」→「API设置」
3. 获取 AppID 和 AppSecret
