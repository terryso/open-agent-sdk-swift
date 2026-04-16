# Story 17.9: 沙盒配置增强

Status: backlog

## Story

作为 SDK 开发者，
我希望补齐 Swift SDK 中缺失的 SandboxNetworkConfig 和 5 个 SandboxSettings 字段，
以便所有安全控制都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: SandboxNetworkConfig** -- 新增 `SandboxNetworkConfig` 结构包含: allowedDomains: [String], allowManagedDomainsOnly: Bool, allowLocalBinding: Bool, allowUnixSockets: Bool, allowAllUnixSockets: Bool, httpProxyPort: Int?, socksProxyPort: Int?.

2. **AC2: SandboxSettings 字段补全** -- 新增: autoAllowBashIfSandboxed: Bool, allowUnsandboxedCommands: Bool, ignoreViolations: [String: [String]]?, enableWeakerNestedSandbox: Bool, ripgrep: RipgrepConfig?, network: SandboxNetworkConfig?.

3. **AC3: autoAllowBashIfSandboxed 行为** -- sandbox 启用 + autoAllowBashIfSandboxed=true 时, BashTool 跳过 canUseTool 检查自动执行, 但仍在沙盒环境中运行.

4. **AC4: allowUnsandboxedCommands 行为** -- 允许模型通过 dangerouslyDisableSandbox 请求非沙盒执行, 回退到 canUseTool 回调授权.

5. **AC5: ignoreViolations 模式** -- 按类别忽略违规: { "file": ["/tmp/*"], "network": ["localhost"] }.

6. **AC6: RipgrepConfig** -- 新增 RipgrepConfig 结构: command: String, args: [String]?.

7. **AC7: 构建和测试** -- swift build 零错误零警告，3400+ 测试零回归.

## Tasks / Subtasks

- [ ] Task 1: SandboxNetworkConfig (AC: #1)
  - [ ] 创建 SandboxNetworkConfig 结构 (7 个字段)
  - [ ] 所有字段有合理默认值
  - [ ] 在 SandboxSettings 中添加 network 字段

- [ ] Task 2: SandboxSettings 字段 (AC: #2, #6)
  - [ ] 添加 autoAllowBashIfSandboxed (默认 false)
  - [ ] 添加 allowUnsandboxedCommands (默认 false)
  - [ ] 添加 ignoreViolations (可选)
  - [ ] 添加 enableWeakerNestedSandbox (默认 false)
  - [ ] 创建 RipgrepConfig 类型并添加 ripgrep 字段
  - [ ] 更新 init 方法

- [ ] Task 3: autoAllowBashIfSandboxed 逻辑 (AC: #3)
  - [ ] 在 BashTool 执行前检查此标志
  - [ ] true 时跳过 canUseTool 但仍执行沙盒检查

- [ ] Task 4: allowUnsandboxedCommands 逻辑 (AC: #4)
  - [ ] BashTool 的 dangerouslyDisableSandbox 回退逻辑
  - [ ] 回退到 canUseTool 回调授权

- [ ] Task 5: ignoreViolations 逻辑 (AC: #5)
  - [ ] 在 SandboxChecker 中集成违规忽略规则
  - [ ] 按类别匹配路径/命令

- [ ] Task 6: 验证构建和测试 (AC: #7)

## Dev Notes

### 关键源文件
- `Sources/OpenAgentSDK/Types/SandboxSettings.swift` -- SandboxSettings 结构
- `Sources/OpenAgentSDK/Utils/SandboxChecker.swift` -- 沙盒检查逻辑
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- BashTool 沙盒集成

### 缺口来源
- Story 16-12: 18 MISSING (SandboxNetworkConfig 7 fields, 5 SandboxSettings fields, behaviors)

### 实现策略
- SandboxNetworkConfig 字段是声明性的 — 网络过滤实际执行需要 OS 级沙盒支持
- autoAllowBashIfSandboxed 仅影响权限检查流程，不影响沙盒命令过滤
- ignoreViolations 用于开发/测试场景，生产环境应谨慎使用

### References
- [Story 16-12 兼容性报告](_bmad-output/implementation-artifacts/16-12-sandbox-config-compat.md)
