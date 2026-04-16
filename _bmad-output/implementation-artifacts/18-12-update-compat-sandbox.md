# Story 18.12: 更新 CompatSandbox 示例

Status: backlog

## Story

作为 SDK 开发者，
我希望更新 `Examples/CompatSandbox/` 使其反映 Epic 17 填补后的兼容性状态，
以便沙盒配置兼容性报告准确展示对齐程度。

## Acceptance Criteria

1. **AC1: SandboxNetworkConfig PASS** -- 7 个字段 (allowedDomains, allowManagedDomainsOnly, allowLocalBinding, allowUnixSockets, allowAllUnixSockets, httpProxyPort, socksProxyPort) 标记为 `[PASS]`.
2. **AC2: SandboxSettings 字段 PASS** -- autoAllowBashIfSandboxed/allowUnsandboxedCommands/ignoreViolations/enableWeakerNestedSandbox/ripgrep 标记为 `[PASS]`.
3. **AC3: autoAllowBashIfSandboxed 行为验证** -- 实际测试沙盒+autoAllow 下 Bash 自动执行.
4. **AC4: 构建通过** -- swift build 零错误零警告.

## Tasks / Subtasks

- [ ] Task 1: 更新 SandboxNetworkConfig 验证 (AC: #1)
  - [ ] 创建 SandboxNetworkConfig 实例
  - [ ] 验证 7 个字段可设置
  - [ ] 更新报告条目

- [ ] Task 2: 更新 SandboxSettings 字段验证 (AC: #2)
  - [ ] 测试 autoAllowBashIfSandboxed 设置
  - [ ] 测试 allowUnsandboxedCommands 设置
  - [ ] 测试 ignoreViolations 模式
  - [ ] 测试 ripgrep 配置

- [ ] Task 3: autoAllowBashIfSandboxed 行为测试 (AC: #3)
  - [ ] 配置 sandbox + autoAllowBashIfSandboxed=true
  - [ ] 执行 Bash 命令，验证跳过 canUseTool
  - [ ] 验证命令仍在沙盒环境中运行

- [ ] Task 4: 验证构建 (AC: #4)

## Dev Notes

### 依赖
- Story 17-9 (沙盒配置增强)

### 关键源文件
- `Examples/CompatSandbox/main.swift` — 需要更新的示例

### References
- [Story 16-12 兼容性报告](_bmad-output/implementation-artifacts/16-12-sandbox-config-compat.md)
- [Story 17-9](_bmad-output/implementation-artifacts/17-9-sandbox-config-enhancement.md)
