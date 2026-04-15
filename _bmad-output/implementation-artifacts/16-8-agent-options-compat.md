# Story 16.8: Agent Options 完整参数验证

Status: pending

## Story

作为 SDK 开发者，
我希望验证 Swift SDK 的 `AgentOptions` / `SDKConfiguration` 覆盖 TypeScript SDK 的所有 Options 字段，
以便开发者迁移时不需要妥协功能。

## Acceptance Criteria

1. **AC1: 示例编译运行** -- 给定 `Examples/CompatOptions/` 目录和 `CompatOptions` 可执行目标，运行 `swift build` 编译无错误和警告。

2. **AC2: 核心配置字段验证** -- 逐一检查 Swift SDK 是否支持 TS SDK 的核心 Options 字段：
   - `allowedTools: [String]` — 工具白名单
   - `disallowedTools: [String]` — 工具黑名单
   - `maxTurns: Int` — 最大轮次
   - `maxBudgetUsd: Double` — 最大预算
   - `model: String` — 模型选择
   - `fallbackModel: String` — 备用模型
   - `systemPrompt: String` — 系统提示词（含 preset 模式 `{ type: "preset", preset: "claude_code", append?: string }`）
   - `permissionMode: PermissionMode` — 权限模式
   - `canUseTool: CanUseTool` — 自定义授权回调
   - `cwd: String` — 工作目录
   - `env: [String: String]` — 环境变量
   - `mcpServers: [String: McpServerConfig]` — MCP 服务器

3. **AC3: 高级配置字段验证** -- 检查 Swift SDK 是否支持高级 Options：
   - `thinking: ThinkingConfig`（adaptive/enabled/disabled）
   - `effort: String`（low/medium/high/max）
   - `hooks` 配置
   - `sandbox: SandboxSettings`
   - `agents: [String: AgentDefinition]` — subagent 定义
   - `toolConfig: ToolConfig`（askUserQuestion preview 格式）
   - `outputFormat: { type: "json_schema", schema }` — 结构化输出
   - `includePartialMessages: Bool` — 部分消息流
   - `promptSuggestions: Bool` — 提示建议

4. **AC4: 会话配置字段验证** -- 检查会话相关选项：resume、continue、forkSession、resumeSessionAt、sessionId、persistSession。

5. **AC5: 扩展配置字段验证** -- 检查扩展选项：
   - `settingSources: [SettingSource]`（user/project/local）
   - `plugins: [SdkPluginConfig]`
   - `betas: [SdkBeta]`
   - `additionalDirectories: [String]`
   - `debug: Bool` / `debugFile: String`
   - `stderr` 回调
   - `strictMcpConfig: Bool`
   - `extraArgs`
   标记 `executable`、`spawnClaudeCodeProcess`、`pathToClaudeCodeExecutable` 为 N/A（TypeScript 运行时特有）。

6. **AC6: ThinkingConfig 三种模式验证** -- 验证 Swift SDK 支持与 TS SDK 完全一致的 ThinkingConfig：`{ type: "adaptive" }`、`{ type: "enabled", budgetTokens?: number }`、`{ type: "disabled" }`。验证 effort 与 thinking 的联动。

7. **AC7: systemPrompt preset 模式验证** -- 验证 Swift SDK 是否支持 TS SDK 的 preset 系统提示模式（`{ type: "preset", preset: "claude_code", append?: string }`）。如果不支持，记录缺口。

8. **AC8: outputFormat 结构化输出验证** -- 验证 Swift SDK 是否支持通过 JSON Schema 定义输出格式。如果不支持，记录缺口并设计改造方案。

9. **AC9: 兼容性报告输出** -- 对所有 Options 字段输出兼容性状态，按 P0/P1/P2/N/A 分级。

## Tasks / Subtasks

- [ ] Task 1: 创建示例目录和文件 (AC: #1)
- [ ] Task 2: 核心配置字段逐一设置和验证 (AC: #2)
  - [ ] 为每个核心字段编写设置代码
  - [ ] 运行并验证字段生效
- [ ] Task 3: 高级配置字段检查 (AC: #3, #6, #7, #8)
  - [ ] ThinkingConfig 三种模式测试
  - [ ] effort 级别测试
  - [ ] systemPrompt preset 模式检查
  - [ ] outputFormat 检查
- [ ] Task 4: 会话和扩展配置检查 (AC: #4, #5)
  - [ ] 会话恢复选项
  - [ ] settingSources/plugins/betas 等
- [ ] Task 5: 生成兼容性报告 (AC: #9)

## Dev Notes

### 字段优先级

- **P0 核心**：allowedTools, disallowedTools, maxTurns, maxBudgetUsd, model, systemPrompt, permissionMode, canUseTool, cwd, mcpServers
- **P1 高级**：thinking, effort, hooks, sandbox, agents, outputFormat, includePartialMessages
- **P2 扩展**：settingSources, plugins, betas, promptSuggestions, toolConfig
- **N/A**：executable, spawnClaudeCodeProcess, pathToClaudeCodeExecutable, permissionPromptToolName

### 重点缺口分析方向

1. **disallowedTools** — 工具黑名单，优先级高于 allowedTools
2. **outputFormat** — 结构化输出，需要 SDK 支持 JSON Schema 输出
3. **effort** — 努力级别，需验证是否与 ThinkingConfig 联动
4. **systemPrompt preset** — 预设系统提示模式
5. **settingSources** — 控制是否加载文件系统设置
6. **includePartialMessages** — 流式部分消息

### 参考文档

- [TypeScript SDK] Options、ThinkingConfig、SettingSource、ToolConfig、SdkPluginConfig
- [Source] Sources/OpenAgentSDK/Types/AgentOptions.swift — AgentOptions struct
- [Source] Sources/OpenAgentSDK/Types/SDKConfiguration.swift — SDKConfiguration struct
