---
title: 'Linux 平台支持'
type: 'feature'
created: '2026-04-27'
status: 'done'
baseline_commit: 'b3d39a2'
context:
  - '{project-root}/_bmad-output/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** SDK 当前仅声明并测试 macOS 平台。虽然代码设计时已考虑跨平台，但硬编码的 `/bin/bash` 路径、不一致的 home 目录获取方式、以及仅 macOS 的 CI，导致 SDK 无法在 Linux 上实际编译和运行。

**Approach:** 提取跨平台 shell 检测工具函数，统一 home 目录获取逻辑，添加 Linux CI job，通过 Docker/CI 验证 Ubuntu 上的编译。

## Boundaries & Constraints

**Always:** 所有变更必须在 macOS 13+ 上零回归。仅使用 Foundation/POSIX API，禁止引入 Apple 专有框架。优先使用跨平台抽象而非 `#if os(...)` 条件编译。

**Ask First:** 官方支持的 Linux 发行版范围（Ubuntu 20.04+ / 22.04）。是否添加 Dockerfile 用于本地 Linux 测试。

**Never:** 不变更 public API 接口。不引入新依赖。不修改 Swift Concurrency 行为。不触碰与跨平台无关的代码。

</frozen-after-approval>

## Code Map

- `Sources/OpenAgentSDK/Utils/PlatformUtils.swift` -- **新建文件**：跨平台 shell 路径和 home 目录工具函数
- `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- Shell 进程执行，2 处硬编码 `/bin/bash`（184、238 行）
- `Sources/OpenAgentSDK/Utils/GitContextCollector.swift` -- Git 上下文采集，硬编码 `/bin/bash`（29 行）
- `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` -- Shell hook 执行，硬编码 `/bin/bash`（57 行）
- `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- 含 `#if os(Linux)` home 目录块（372 行），待统一
- `Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift` -- 使用 `NSHomeDirectory()` 无 Linux 保护（112 行）
- `Sources/OpenAgentSDK/Skills/SkillLoader.swift` -- 使用 `NSHomeDirectory()` 有 fallback（273 行）
- `Sources/OpenAgentSDK/Utils/FileCache.swift` -- 已有 `#if os(macOS)` 条件编译（308 行），无需修改
- `Sources/OpenAgentSDK/Tools/MCP/MCPStdioTransport.swift` -- 已有 `#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)`，无需修改
- `.github/workflows/ci.yml` -- 当前仅 macOS CI

## Tasks & Acceptance

**Execution:**
- [x] `Sources/OpenAgentSDK/Utils/PlatformUtils.swift` -- 新建文件，包含两个 `static` 工具方法：`shellPath()`（依次查找 `$SHELL`、`/bin/bash`、`/usr/bin/bash`、`/bin/sh`）和 `homeDirectory()`（读取 `$HOME`，macOS 回退 `NSHomeDirectory()`，Linux 回退 `/tmp`）-- 将所有平台相关路径逻辑集中到一处
- [x] `Sources/OpenAgentSDK/Tools/Core/BashTool.swift` -- 将两处 `"/bin/bash"` 字面量替换为 `PlatformUtils.shellPath()` -- 确保 bash 工具在 bash 位于 `/usr/bin/bash` 的 Linux 发行版上正常工作
- [x] `Sources/OpenAgentSDK/Utils/GitContextCollector.swift` -- 将 `"/bin/bash"` 替换为 `PlatformUtils.shellPath()` -- 同上
- [x] `Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift` -- 将 `"/bin/bash"` 替换为 `PlatformUtils.shellPath()` -- 同上
- [x] `Sources/OpenAgentSDK/Stores/SessionStore.swift` -- 将 `#if os(Linux)` / `NSHomeDirectory()` 块（371-380 行）替换为 `PlatformUtils.homeDirectory()` -- 统一 home 目录获取，消除重复条件编译
- [x] `Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift` -- 将 `NSHomeDirectory()` fallback（112 行）替换为 `PlatformUtils.homeDirectory()` -- 保持跨平台行为一致
- [x] `Sources/OpenAgentSDK/Skills/SkillLoader.swift` -- 将 `NSHomeDirectory()` fallback（273 行）替换为 `PlatformUtils.homeDirectory()` -- 保持跨平台行为一致
- [x] `.github/workflows/ci.yml` -- 添加 `test-linux` job，使用 `swift:5.9-jammy` Docker 容器在 `ubuntu-latest` 上运行 -- 确保每个 PR 都在 Linux 上编译和测试通过
- [x] `Tests/OpenAgentSDKTests/Utils/PlatformUtilsTests.swift` -- 新建测试文件，覆盖 `shellPath()` 和 `homeDirectory()` 在两个平台上的行为，mock 环境变量 -- 独立验证工具函数逻辑

**Acceptance Criteria:**
- Given `PlatformUtils.shellPath()`，when `$SHELL` 设为 `/usr/bin/zsh`，then 返回 `/usr/bin/zsh`
- Given `PlatformUtils.shellPath()`，when `$SHELL` 未设置且 `/bin/bash` 存在，then 返回 `/bin/bash`
- Given `PlatformUtils.homeDirectory()`，when `$HOME` 已设置，then 返回该值
- Given 全量测试套件，when 所有变更后在 macOS 上运行，then 所有现有测试通过，零回归
- Given CI 流水线，when 打开 PR，then macOS 和 Linux job 均通过

## Spec Change Log

## Verification

**Commands:**
- `swift build` -- expected: macOS 上零错误编译
- `swift test` -- expected: macOS 上全量测试通过，零回归
- CI `test-linux` job -- expected: Ubuntu Docker 容器中 `swift build && swift test` 通过

## Suggested Review Order

**跨平台抽象入口**
- 核心设计：集中所有平台路径逻辑的两个 static 方法
  [`PlatformUtils.swift:13`](../../Sources/OpenAgentSDK/Utils/PlatformUtils.swift#L13)

**Shell 路径替换（4 个调用点）**
- BashTool 前台进程执行，两处替换
  [`BashTool.swift:184`](../../Sources/OpenAgentSDK/Tools/Core/BashTool.swift#L184)
- Git 上下文采集
  [`GitContextCollector.swift:29`](../../Sources/OpenAgentSDK/Utils/GitContextCollector.swift#L29)
- Shell hook 执行
  [`ShellHookExecutor.swift:57`](../../Sources/OpenAgentSDK/Hooks/ShellHookExecutor.swift#L57)

**Home 目录统一（3 个调用点）**
- SessionStore 用 PlatformUtils 替代 9 行条件编译
  [`SessionStore.swift:371`](../../Sources/OpenAgentSDK/Stores/SessionStore.swift#L371)
- 项目文档发现
  [`ProjectDocumentDiscovery.swift:112`](../../Sources/OpenAgentSDK/Utils/ProjectDocumentDiscovery.swift#L112)
- Skill 加载器的 tilde 展开
  [`SkillLoader.swift:273`](../../Sources/OpenAgentSDK/Skills/SkillLoader.swift#L273)

**CI 与测试**
- Linux CI job（swift:6.1-jammy Docker）
  [`ci.yml:49`](../../.github/workflows/ci.yml#L49)
- PlatformUtils 单元测试（8 个用例）
  [`PlatformUtilsTests.swift:6`](../../Tests/OpenAgentSDKTests/Utils/PlatformUtilsTests.swift#L6)
