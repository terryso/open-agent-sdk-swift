# Story 16.12: Sandbox 配置兼容性验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 Sandbox 配置完全覆盖 TypeScript SDK 的所有沙盒选项，
以便所有安全控制都能在 Swift 中使用。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatSandbox/` 目录和 `CompatSandbox` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: SandboxSettings 完整字段验证** -- 检查 Swift SDK 的 SandboxSettings 是否包含 TS SDK 的所有顶层字段：
   - `enabled: Bool` — 启用沙盒
   - `autoAllowBashIfSandboxed: Bool` — 沙盒中自动批准 Bash
   - `excludedCommands: [String]` — 始终绕过沙盒的命令
   - `allowUnsandboxedCommands: Bool` — 允许模型请求非沙盒执行
   - `network: SandboxNetworkConfig?` — 网络配置
   - `filesystem: SandboxFilesystemConfig?` — 文件系统配置
   - `ignoreViolations: [String: [String]]?` — 违规忽略规则
   - `enableWeakerNestedSandbox: Bool` — 嵌套沙盒弱化
   - `ripgrep: { command, args? }?` — 自定义 ripgrep 配置

3. **AC3: SandboxNetworkConfig 验证** -- 检查 Swift SDK 是否有网络沙盒配置等价类型，包含 TS SDK 的字段：allowedDomains、allowManagedDomainsOnly、allowLocalBinding、allowUnixSockets、allowAllUnixSockets、httpProxyPort、socksProxyPort。如未实现，标记为 v2.0 候选。

4. **AC4: SandboxFilesystemConfig 验证** -- 检查 Swift SDK 的文件系统沙盒配置包含 TS SDK 的字段：allowWrite（允许写入路径）、denyWrite（禁止写入路径）、denyRead（禁止读取路径）。

5. **AC5: autoAllowBashIfSandboxed 行为验证** -- 设置 `sandbox.enabled = true` + `autoAllowBashIfSandboxed = true`，验证 BashTool 自动执行而无需额外授权。

6. **AC6: excludedCommands vs allowUnsandboxedCommands 验证** -- 验证两者的区别：excludedCommands 是静态列表（模型无控制权），allowUnsandboxedCommands 允许模型在运行时通过 dangerouslyDisableSandbox 请求非沙盒执行（回退到 canUseTool）。

7. **AC7: dangerouslyDisableSandbox 回退验证** -- 验证 BashTool 的 `dangerouslyDisableSandbox` 输入字段，启用时回退到 canUseTool 回调。验证 canUseTool 回调能识别此请求并实现自定义授权。

8. **AC8: ignoreViolations 模式验证** -- 验证违规忽略规则按类别匹配（如 `{ "file": ["/tmp/*"], "network": ["localhost"] }`）。

9. **AC9: 兼容性报告输出** -- 对所有 SandboxSettings 字段和网络/文件系统子配置输出兼容性状态。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: SandboxSettings 字段检查 (AC: #2)
  - [ ] 对比 TS SDK SandboxSettings 的每个字段
  - [ ] 记录缺失字段
- [ ] Task 3: 网络和文件系统配置检查 (AC: #3, #4)
  - [ ] 检查 SandboxNetworkConfig 等价
  - [ ] 检查 SandboxFilesystemConfig 字段
- [ ] Task 4: 行为验证 (AC: #5, #6, #7, #8)
  - [ ] 测试 autoAllowBashIfSandboxed
  - [ ] 测试 excludedCommands 列表
  - [ ] 测试 dangerouslyDisableSandbox + canUseTool 回退
  - [ ] 测试 ignoreViolations
- [ ] Task 5: 生成兼容性报告 (AC: #9)

## Dev Notes

### 参考文档

- [TypeScript SDK] SandboxSettings、SandboxNetworkConfig、SandboxFilesystemConfig、BashInput（dangerouslyDisableSandbox 字段）
- [Source] Sources/OpenAgentSDK/Types/SandboxTypes.swift — SandboxSettings
- [Source] Sources/OpenAgentSDK/Tools/Core/BashTool.swift — BashTool 沙盒集成
