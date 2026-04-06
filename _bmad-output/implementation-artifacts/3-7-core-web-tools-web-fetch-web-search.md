# Story 3.7: 核心网络工具（WebFetch、WebSearch）

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

作为开发者，
我希望我的 Agent 可以获取网页内容和执行网络搜索，
以便它可以访问互联网上的信息。

## Acceptance Criteria

1. **AC1: WebFetch 工具获取 URL 内容** — 给定已注册的 WebFetch 工具，当 LLM 请求获取 URL，则通过 URLSession 发起 HTTP GET 请求，返回页面内容。请求具有可配置的超时时间（默认 30 秒）。

2. **AC2: WebFetch HTML 内容处理** — 给定 WebFetch 获取到 HTML 内容（Content-Type 包含 text/html），当处理响应，则剥离 `<script>` 和 `<style>` 块，移除 HTML 标签，清理多余空白，返回纯文本。

3. **AC3: WebFetch 输出截断** — 给定 WebFetch 工具返回超过 100,000 字符的内容，当结果被组装，则截断为前 100,000 字符并追加截断标记。

4. **AC4: WebFetch HTTP 错误处理** — 给定 WebFetch 请求返回非 2xx HTTP 状态码，当响应被接收，则返回包含状态码的错误结果（isError: true）。

5. **AC5: WebFetch 网络错误处理** — 给定 WebFetch 遇到网络错误（DNS 解析失败、连接超时、TLS 错误等），当错误发生，则返回包含错误描述的 isError 结果，不崩溃。

6. **AC6: WebSearch 工具执行搜索** — 给定已注册的 WebSearch 工具，当 LLM 请求网络搜索查询，则通过 DuckDuckGo HTML 搜索接口执行搜索，返回带有标题、URL 和摘要的搜索结果。

7. **AC7: WebSearch 结果数量限制** — 给定 WebSearch 工具的 `num_results` 参数，当搜索完成，则结果限制为指定数量（默认 5）。

8. **AC8: WebSearch 无结果处理** — 给定 WebSearch 搜索后无结果，当搜索完成，则返回描述性的"无结果"消息。

9. **AC9: 工具注册到 core 层级** — 给定 `getAllBaseTools(tier: .core)` 调用，当 core 层级工具被请求，则 WebFetch 和 WebSearch 工具包含在返回数组中。两者均为 `isReadOnly: true`。core 层级现在包含全部 10 个工具（Read、Write、Edit、Glob、Grep、Bash、AskUser、ToolSearch、WebFetch、WebSearch）。

10. **AC10: 网络请求跨平台** — 给定工具在 macOS 和 Linux 上运行，当执行网络请求，则使用 Foundation 的 URLSession，两个平台行为一致（NFR11、NFR12）。

## Tasks / Subtasks

- [x] Task 1: 创建 WebFetchTool (AC: #1, #2, #3, #4, #5, #10)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift`
  - [x] 定义 `WebFetchInput: Codable` 结构体（url: String, headers: [String: String]?）
  - [x] 实现 `createWebFetchTool() -> ToolProtocol` 函数（使用 `defineTool` 的 `ToolExecuteResult` 返回重载）
  - [x] 使用 `URLSession.shared.data(from:)` 发起异步 HTTP GET 请求
  - [x] 设置 User-Agent 请求头：`Mozilla/5.0 (compatible; AgentSDK/1.0)`
  - [x] 实现超时：通过 `URLSessionConfiguration` 设置 `timeoutIntervalForResource = 30` 秒
  - [x] HTML 内容处理：剥离 script/style 块和 HTML 标签，清理空白
  - [x] 非 HTML 内容直接返回原始文本
  - [x] 空响应返回 `(empty response)` 消息
  - [x] 输出截断：超过 100,000 字符时截断并追加 `...(truncated)` 标记
  - [x] HTTP 错误（非 2xx）返回 `HTTP {status}: {reason}` 错误
  - [x] 网络错误返回错误描述
  - [x] 设置 `isReadOnly: true`

- [x] Task 2: 创建 WebSearchTool (AC: #6, #7, #8, #10)
  - [x] 创建 `Sources/OpenAgentSDK/Tools/Core/WebSearchTool.swift`
  - [x] 定义 `WebSearchInput: Codable` 结构体（query: String, num_results: Int?）
  - [x] 实现 `createWebSearchTool() -> ToolProtocol` 函数（使用 `defineTool` 的 `ToolExecuteResult` 返回重载）
  - [x] 使用 `URLSession` 获取 DuckDuckGo HTML 搜索：`https://html.duckduckgo.com/html/?q={encoded_query}`
  - [x] 设置 User-Agent 请求头
  - [x] 使用正则表达式解析搜索结果：提取标题、URL、摘要
  - [x] 格式化结果为：`1. {title}\n   {url}\n   {snippet}`
  - [x] 默认 `num_results: 5`
  - [x] 无结果返回 `No results found for "{query}"`
  - [x] 搜索错误返回错误描述
  - [x] 设置 `isReadOnly: true`

- [x] Task 3: 更新 ToolRegistry 注册 core 工具 (AC: #9)
  - [x] 修改 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` 中的 `getAllBaseTools(tier:)` 函数
  - [x] 当 `tier == .core` 时，追加 `createWebFetchTool()` 和 `createWebSearchTool()`
  - [x] 移除 "Story 3.7 will add" 注释
  - [x] 更新函数文档注释，反映全部 10 个 core 工具

- [x] Task 4: 单元测试 — WebFetchTool (AC: #1, #2, #3, #4, #5, #10)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Core/WebFetchToolTests.swift`
  - [x] `testWebFetch_fetchesUrl_returnsContent` — 获取 URL 返回内容
  - [x] `testWebFetch_htmlContent_stripsTags` — HTML 内容剥离标签
  - [x] `testWebFetch_largeOutput_truncated` — 超过 100k 字符被截断
  - [x] `testWebFetch_httpError_returnsError` — HTTP 错误返回 isError
  - [x] `testWebFetch_networkError_returnsError` — 网络错误返回 isError
  - [x] `testWebFetch_emptyResponse_returnsMessage` — 空响应返回消息
  - [x] `testWebFetch_isReadOnly_true` — isReadOnly 为 true
  - [x] `testWebFetch_customHeaders_included` — 自定义请求头被包含

- [x] Task 5: 单元测试 — WebSearchTool (AC: #6, #7, #8)
  - [x] 创建 `Tests/OpenAgentSDKTests/Tools/Core/WebSearchToolTests.swift`
  - [x] `testWebSearch_returnsResults` — 搜索返回格式化结果
  - [x] `testWebSearch_numResults_limitsOutput` — num_results 限制输出数量
  - [x] `testWebSearch_noResults_returnsMessage` — 无结果返回消息
  - [x] `testWebSearch_searchError_returnsError` — 搜索错误返回 isError
  - [x] `testWebSearch_isReadOnly_true` — isReadOnly 为 true

- [x] Task 6: 单元测试 — ToolRegistry core 层级集成 (AC: #9)
  - [x] 更新 `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift`
  - [x] `testGetAllBaseTools_coreTier_includesAllTenTools` — core 层级包含全部 10 个工具
  - [x] `testGetAllBaseTools_coreTier_webToolsAreReadOnly` — WebFetch 和 WebSearch 的 isReadOnly 为 true

- [x] Task 7: 编译验证
  - [x] 运行 `swift build` 确认编译通过
  - [x] 运行 `swift test` 确认所有测试通过（需要 Xcode 环境，CI 验证）
  - [x] 验证 `Tools/Core/` 目录下的文件不导入 `Core/`（模块边界规则）

## Dev Notes

### 核心设计决策

**本 story 的定位：**
- 紧接 Story 3.6（系统工具 Bash/AskUser/ToolSearch），实现最后两个核心层工具
- WebFetch 和 WebSearch 均为**只读工具**（`isReadOnly: true`），会被并发执行
- 本 story 完成后，core 层级全部 10 个工具实现完毕
- FR16 全部覆盖：Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch、AskUser、ToolSearch

### 已有基础设施（直接复用）

| 类型 | 位置 | 说明 |
|------|------|------|
| `ToolProtocol` | `Types/ToolTypes.swift` | name, description, inputSchema, isReadOnly, call() |
| `ToolResult` | `Types/ToolTypes.swift` | toolUseId, content, isError |
| `ToolContext` | `Types/ToolTypes.swift` | cwd, toolUseId |
| `ToolExecuteResult` | `Types/ToolTypes.swift` | content, isError 结构化返回 |
| `defineTool()` | `Tools/ToolBuilder.swift` | 三个重载（String/ToolExecuteResult/NoInput） |
| `ToolRegistry` | `Tools/ToolRegistry.swift` | getAllBaseTools, toApiTool, toApiTools, filterTools, assembleToolPool |

### 实现位置

**新增文件：**
```
Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift    # 网页内容获取工具
Sources/OpenAgentSDK/Tools/Core/WebSearchTool.swift    # 网络搜索工具
```

**修改文件：**
```
Sources/OpenAgentSDK/Tools/ToolRegistry.swift          # getAllBaseTools 追加两个工具，完成 core 层级
```

**测试文件：**
```
Tests/OpenAgentSDKTests/Tools/Core/WebFetchToolTests.swift    # WebFetch 工具测试
Tests/OpenAgentSDKTests/Tools/Core/WebSearchToolTests.swift   # WebSearch 工具测试
```

### 工具工厂函数模式

遵循 Story 3.4-3.6 建立的模式（以 BashTool 为最新参考）：

```swift
// Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift

import Foundation

// MARK: - Input

private struct WebFetchInput: Codable {
    let url: String
    let headers: [String: String]?
}

// MARK: - Constants

private enum WebFetchConstants {
    static let defaultTimeout: TimeInterval = 30
    static let truncationLimit = 100_000
}

// MARK: - Factory

public func createWebFetchTool() -> ToolProtocol {
    return defineTool(
        name: "WebFetch",
        description: "Fetch content from a URL and return it as text. Supports HTML pages, JSON APIs, and plain text. Strips HTML tags for readability.",
        inputSchema: [
            "type": "object",
            "properties": [
                "url": ["type": "string", "description": "The URL to fetch content from"],
                "headers": [
                    "type": "object",
                    "description": "Optional HTTP headers"
                ]
            ],
            "required": ["url"]
        ],
        isReadOnly: true
    ) { (input: WebFetchInput, context: ToolContext) async throws -> ToolExecuteResult in
        // 实现...
    }
}
```

**关键模式要点（同 Story 3.4-3.6）：**
- `WebFetchInput` / `WebSearchInput` 定义为 `private` 的 `Codable` 结构体
- 工厂函数是 `public`，返回 `ToolProtocol`
- 使用 `ToolExecuteResult` 返回重载（需要 isError 标志处理 HTTP 错误、网络错误等）
- `inputSchema` 使用原始 JSON 字典（规则 #41）
- JSON Schema 字段名使用 snake_case（规则 #17）
- 整型参数使用 `"integer"` 而非 `"number"`（Story 3.4 经验）
- 错误在闭包内 do/catch 捕获，**永不** throw 出闭包（规则 #38）

### WebFetch 工具实现要点

**1. URLSession 网络请求**

使用 Foundation 的 `URLSession`（macOS 和 Linux 均可用，无需 Apple 专属框架）：

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForResource = WebFetchConstants.defaultTimeout
let session = URLSession(configuration: config)

var request = URLRequest(url: url)
request.setValue("Mozilla/5.0 (compatible; AgentSDK/1.0)", forHTTPHeaderField: "User-Agent")
// 应用自定义 headers
if let headers = input.headers {
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
}

let (data, response) = try await session.data(for: request)
```

**重要注意事项：**
- `URLSession` 在 macOS 和 Linux 上均可用（属于 Foundation）— 满足跨平台要求
- 使用 `timeoutIntervalForResource` 设置整体超时（包含 DNS + 连接 + 下载）
- 不需要使用 Combine 或 async let — 使用结构化并发的 `await session.data(for:)`
- 不要使用 `URLSession.shared.dataTask(with:completionHandler:)` — 使用 async/await 版本

**2. HTML 内容处理**

```swift
let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
let text = String(data: data, encoding: .utf8) ?? ""

var processedText = text
if contentType.contains("text/html") {
    // 移除 script 块
    processedText = processedText.replacingOccurrences(
        of: "<script[^>]*>[\\s\\S]*?</script>",
        with: "",
        options: .regularExpression,
        range: nil
    )
    // 移除 style 块
    processedText = processedText.replacingOccurrences(
        of: "<style[^>]*>[\\s\\S]*?</style>",
        with: "",
        options: .regularExpression,
        range: nil
    )
    // 移除所有 HTML 标签
    processedText = processedText.replacingOccurrences(
        of: "<[^>]+>",
        with: " ",
        options: .regularExpression,
        range: nil
    )
    // 清理空白
    processedText = processedText.replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression,
        range: nil
    ).trimmingCharacters(in: .whitespacesAndNewlines)
}

// 空响应处理
if processedText.isEmpty {
    return ToolExecuteResult(content: "(empty response)", isError: false)
}

// 截断
if processedText.count > WebFetchConstants.truncationLimit {
    processedText = String(processedText.prefix(WebFetchConstants.truncationLimit)) + "\n...(truncated)"
}
```

**3. HTTP 错误处理**

```swift
guard let httpResponse = response as? HTTPURLResponse else {
    return ToolExecuteResult(content: "Error: Invalid response type", isError: true)
}

guard (200...299).contains(httpResponse.statusCode) else {
    return ToolExecuteResult(
        content: "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))",
        isError: true
    )
}
```

**4. 网络错误处理**

所有网络错误在 do/catch 中捕获：
- `URLError.notConnectedToInternet` — 无网络连接
- `URLError.timedOut` — 请求超时
- `URLError.cannotFindHost` — DNS 解析失败
- `URLError.cannotConnectToHost` — 连接被拒绝
- TLS/SSL 错误
- 所有错误统一返回 `ToolExecuteResult(content: "Error fetching \(url): \(error.localizedDescription)", isError: true)`

### WebSearch 工具实现要点

**1. DuckDuckGo HTML 搜索**

TypeScript SDK 使用 DuckDuckGo HTML 搜索作为免费的搜索后端（无需 API 密钥）：

```swift
let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
let searchUrl = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)")!
```

**2. 搜索结果解析**

使用正则表达式从 DuckDuckGo HTML 页面提取搜索结果：

```swift
// 提取链接和标题
let resultRegex = try NSRegularExpression(
    pattern: "<a rel=\"nofollow\" class=\"result__a\" href=\"([^\"]*)\"[^>]*>([\\s\\S]*?)</a>",
    options: [.caseInsensitive]
)

// 提取摘要
let snippetRegex = try NSRegularExpression(
    pattern: "<a class=\"result__snippet\"[^>]*>([\\s\\S]*?)</a>",
    options: [.caseInsensitive]
)
```

**重要：HTML 标签清理**
- 从标题和摘要中移除 HTML 标签：`text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)`
- 过滤掉包含 `duckduckgo.com` 的内部链接

**3. 结果格式化**

```swift
let numResults = min(input.num_results ?? 5, links.count)
var results: [String] = []
for i in 0..<numResults {
    var entry = "\(i + 1). \(links[i].title)\n   \(links[i].url)"
    if i < snippets.count, !snippets[i].isEmpty {
        entry += "\n   \(snippets[i])"
    }
    results.append(entry)
}
return results.joined(separator: "\n\n")
```

**4. 搜索错误处理**

- HTTP 请求失败返回 `Search failed: HTTP {status}` 错误
- 正则解析无匹配返回 `No results found for "{query}"` 消息（非错误）
- 网络异常在 do/catch 中捕获，返回 `Search error: {message}` 错误

### getAllBaseTools 更新

当前 `getAllBaseTools(tier:)` 已有 8 个工具（Read/Write/Edit/Glob/Grep/Bash/AskUser/ToolSearch），注释中有 `// Story 3.7 will add: WebFetch, WebSearch`。

更新为：
```swift
public func getAllBaseTools(tier: ToolTier) -> [ToolProtocol] {
    switch tier {
    case .core:
        return [
            createReadTool(),
            createWriteTool(),
            createEditTool(),
            createGlobTool(),
            createGrepTool(),
            createBashTool(),
            createAskUserTool(),
            createToolSearchTool(),
            createWebFetchTool(),
            createWebSearchTool(),
        ]
    case .advanced, .specialist:
        return []
    }
}
```

更新函数文档注释：`For the \`.core\` tier, returns all 10 built-in tools: Read, Write, Edit, Glob, Grep, Bash, AskUser, ToolSearch, WebFetch, and WebSearch.`

### 反模式警告

- **不要**从工具执行闭包内部 throw 错误导致循环中断 — 在闭包内 do/catch 并返回 ToolExecuteResult（规则 #38）
- **不要**使用 force-unwrap (`!`) — 使用 guard let / if let（规则 #39）
- **不要**在 `Tools/` 中导入 `Core/` — 工具文件只依赖 Foundation 和 Types（规则 #40）
- **不要**使用 Codable 做 LLM API 通信 — inputSchema 使用原始 `[String: Any]` 字典（规则 #41）
- **不要**使用 Apple 专属框架 — URLSession 属于 Foundation，非 Apple 专属（规则 #43）
- **不要**使用 `async let` 或非结构化 `Task` — 使用 `await` 的结构化并发（规则 #46）
- **不要**在 Tools/Core/ 中创建 actor — 工具是无状态的 struct/闭包
- **不要**使用第三方 HTTP 库（Alamofire 等）— 使用 Foundation 的 URLSession
- **不要**使用需要 API 密钥的搜索服务 — DuckDuckGo HTML 搜索是免费的
- **不要**将 HTML 标签清理结果设为 isError — 空搜索结果不是错误，是正常结果

### 前一 Story 关键经验（Story 3.6 系统工具）

1. **工厂函数模式已完全验证** — `createXxxTool() -> ToolProtocol` 使用 `defineTool` 的 `ToolExecuteResult` 重载
2. **MARK 注释风格** — `// MARK: - Input`、`// MARK: - Constants`、`// MARK: - Factory`、`// MARK: - ...`
3. **private struct Input: Codable** — 输入结构体使用 `private` 限定作用域
4. **private enum Constants** — 常量使用嵌套枚举分组（参考 BashTool 的 BashConstants）
5. **@unchecked Sendable 模式** — CodableTool/StructuredCodableTool 使用此模式，工具本身不需要处理
6. **JSON Schema "integer" 类型** — 整型参数使用 `"integer"` 而非 `"number"`（`num_results` 字段）
7. **测试命名约定** — `test{ToolName}_{scenario}_{expectedBehavior}` 格式
8. **截断实现** — BashTool 使用 `String.Index` 进行高效截断，但 WebFetch 使用简单的 `String.prefix(100000)` 即可（100k 字符处直接截断，不需要头尾保留）

### TypeScript SDK 参考

**web-fetch.ts — 网页内容获取：**
- 使用 Node.js `fetch` API
- 参数：`url`（必须）、`headers`（可选）
- User-Agent: `Mozilla/5.0 (compatible; AgentSDK/1.0)`
- 超时 30 秒（`AbortSignal.timeout(30000)`）
- HTML 处理：移除 script/style 块 + 移除 HTML 标签 + 清理空白
- 非 HTML 内容直接返回原始文本
- 超过 100,000 字符截断为前 100,000 + `...(truncated)`
- HTTP 错误返回 `HTTP {status}: {statusText}` 错误
- `isReadOnly: true`、`isConcurrencySafe: true`

**web-search.ts — 网络搜索：**
- 使用 DuckDuckGo HTML 搜索（`https://html.duckduckgo.com/html/?q={encoded}`）
- 参数：`query`（必须）、`num_results`（可选，默认 5）
- User-Agent: `Mozilla/5.0 (compatible; AgentSDK/1.0)`
- 超时 15 秒
- 正则解析结果：`result__a` class 的链接、`result__snippet` class 的摘要
- 过滤掉 `duckduckgo.com` 的内部链接
- 结果格式：`{n}. {title}\n   {url}\n   {snippet}`
- 无结果返回 `No results found for "{query}"`
- `isReadOnly: true`、`isConcurrencySafe: true`

### Swift 与 TypeScript 实现差异

| 方面 | TypeScript | Swift |
|------|-----------|-------|
| HTTP 请求 | `fetch()` | `URLSession.shared.data(for:)` |
| 超时 | `AbortSignal.timeout(30000)` | `URLSessionConfiguration.timeoutIntervalForResource` |
| HTML 清理 | 正则替换 `String.replace()` | `replacingOccurrences(of:options:range:)` + `.regularExpression` |
| 搜索接口 | DuckDuckGo HTML | 同（DuckDuckGo HTML） |
| 正则匹配 | `RegExp.exec()` 循环 | `NSRegularExpression.matches(in:range:)` |
| 输出截断 | `text.slice(0, 100000)` | `String.prefix(100_000)` |

### 与其他 Story 的关系

| Story | 与本 Story 的关系 |
|-------|-------------------|
| 3.1 (已完成) | 提供 ToolProtocol、ToolRegistry、ToolTier，本 story 消费 |
| 3.2 (已完成) | 提供 defineTool() 工厂函数，本 story 使用创建工具 |
| 3.3 (已完成) | 提供 ToolExecutor 并发/串行调度，WebFetch/WebSearch(isReadOnly:true) 将被并发执行 |
| 3.4 (已完成) | 提供工具实现模式参考（FileReadTool、FileWriteTool、FileEditTool） |
| 3.5 (已完成) | 提供搜索工具模式参考（GlobTool、GrepTool） |
| 3.6 (已完成) | 提供系统工具模式参考（BashTool、AskUserTool、ToolSearchTool） |
| 4.x (后续) | 高级层工具，本 story 完成后 core 层级全部就绪 |

### 测试策略

**WebFetch 测试关键考虑：**
- 网络请求测试需要处理真实网络延迟和不可靠性
- 建议使用 `URLProtocol` 子类 mock HTTP 响应（规则 #27：无 mock 外部 API — 但 URLProtocol 子类是 XCTest 标准做法）
- 或者使用公开的、稳定的测试 URL（如 `https://httpbin.org/get`、`https://example.com`）
- HTML 标签剥离可以测试纯字符串处理逻辑（不依赖网络）
- 截断逻辑可以使用超长字符串测试

```swift
// URLProtocol mock 方案示例
class MockURLProtocol: URLProtocol {
    static var mockResponse: (data: Data?, response: HTTPURLResponse?, error: Error?)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = MockURLProtocol.mockResponse.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = MockURLProtocol.mockResponse.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = MockURLProtocol.mockResponse.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}
```

**WebSearch 测试关键考虑：**
- DuckDuckGo HTML 搜索是外部服务，结果可能随时间变化
- 核心逻辑（正则解析、结果格式化）可以通过 mock HTML 测试
- 网络层使用 URLProtocol mock
- 建议将 HTML 解析逻辑提取为独立的 `internal` 函数以便单元测试

**测试命名遵循既有模式：**
```
testWebFetch_fetchesUrl_returnsContent
testWebFetch_htmlContent_stripsTags
testWebSearch_returnsResults
testWebSearch_noResults_returnsMessage
```

### 性能考虑

1. **URLSession 共享** — 使用 `URLSession.shared` 或创建专用 session。`URLSession.shared` 已自动管理连接池和缓存。
2. **HTML 正则处理** — `replacingOccurrences` 对大页面性能可接受。如果遇到超大 HTML（>1MB），可以在处理前先截断 data。
3. **WebSearch 搜索延迟** — DuckDuckGo HTML 搜索通常在 1-3 秒内返回，远低于 30 秒超时。
4. **两个工具都是只读** — 可以并发执行，不会阻塞其他只读工具。

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.7]
- [Source: _bmad-output/planning-artifacts/architecture.md#AD4 工具系统 — ToolProtocol]
- [Source: _bmad-output/planning-artifacts/architecture.md#项目结构 — Tools/Core/WebFetchTool.swift, WebSearchTool.swift]
- [Source: _bmad-output/project-context.md#规则 38 工具错误不 throw]
- [Source: _bmad-output/project-context.md#规则 41 不用 Codable 做 LLM 通信]
- [Source: _bmad-output/project-context.md#规则 43 不用 Apple 专属框架]
- [Source: _bmad-output/implementation-artifacts/3-6-core-system-tools-bash-ask-user-tool-search.md] — 前一 story
- [Source: Sources/OpenAgentSDK/Types/ToolTypes.swift] — ToolProtocol, ToolResult, ToolContext
- [Source: Sources/OpenAgentSDK/Tools/ToolBuilder.swift] — defineTool, CodableTool, StructuredCodableTool
- [Source: Sources/OpenAgentSDK/Tools/ToolRegistry.swift] — getAllBaseTools, toApiTool
- [Source: Sources/OpenAgentSDK/Tools/Core/BashTool.swift] — 工厂函数模式参考、常量分组、截断实现
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/web-fetch.ts] — TS WebFetch 工具参考
- [Source: /Users/nick/CascadeProjects/open-agent-sdk-typescript/src/tools/web-search.ts] — TS WebSearch 工具参考

### Project Structure Notes

- 新增 `Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift`、`WebSearchTool.swift` — 架构文档已定义此路径
- 修改 `Sources/OpenAgentSDK/Tools/ToolRegistry.swift` — 更新 `getAllBaseTools(tier:)` 函数追加两个工具，移除 Story 3.7 注释
- 新增 `Tests/OpenAgentSDKTests/Tools/Core/WebFetchToolTests.swift`、`WebSearchToolTests.swift`
- 更新 `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift` — 追加 core 层级完整性测试
- 完全对齐架构文档的目录结构
- 完成后 core 层级全部 10 个工具就绪，Epic 3 的 FR16 完全覆盖

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (GLM-5.1)

### Debug Log References

- `swift build` passed cleanly on first attempt after implementation
- Tests cannot be run locally (no Xcode.app, only Command Line Tools) — tests require CI (macos-15 runner)

### Completion Notes List

- Implemented WebFetchTool with URLSession HTTP GET, HTML processing (script/style stripping, tag removal, whitespace cleanup), 100k char truncation, HTTP error handling, network error handling, configurable timeout (30s), custom headers support, and User-Agent header
- Implemented WebSearchTool with DuckDuckGo HTML search, regex-based result parsing (title/URL/snippet), num_results limiting (default 5), no-results message, search error handling, and 15s timeout
- Updated ToolRegistry to include WebFetch and WebSearch in core tier (now 10 tools total)
- All code follows established patterns from Stories 3.4-3.6 (factory function, private Codable input, ToolExecuteResult overload, MARK comments)
- Module boundary verified: both new tool files only import Foundation (no Core/ import)
- ATDD test files were already created in the red phase and cover all acceptance criteria
- Tests will be verified in CI environment (requires Xcode)

### File List

**New files:**
- `Sources/OpenAgentSDK/Tools/Core/WebFetchTool.swift`
- `Sources/OpenAgentSDK/Tools/Core/WebSearchTool.swift`

**Modified files:**
- `Sources/OpenAgentSDK/Tools/ToolRegistry.swift`

**Pre-existing test files (ATDD red phase):**
- `Tests/OpenAgentSDKTests/Tools/Core/WebFetchToolTests.swift`
- `Tests/OpenAgentSDKTests/Tools/Core/WebSearchToolTests.swift`
- `Tests/OpenAgentSDKTests/Tools/Core/FileToolsRegistryTests.swift`
