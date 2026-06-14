import Foundation
import OpenAgentSDK

@main
struct AgentHTTPServerExample {
    static func main() async throws {
        let dotEnv = loadDotEnv()
        let apiKey = getEnv("CODEANY_API_KEY", from: dotEnv)
            ?? getEnv("ANTHROPIC_API_KEY", from: dotEnv)
        let model = getEnv("ANTHROPIC_MODEL", from: dotEnv)
            ?? getEnv("CODEANY_MODEL", from: dotEnv)
            ?? "claude-sonnet-4-6"
        let useOpenAI = getEnv("CODEANY_API_KEY", from: dotEnv) != nil
        let baseURL: String? = useOpenAI
            ? getDefaultOpenAIBaseURL(from: dotEnv)
            : getDefaultAnthropicBaseURL(from: dotEnv)
        let host = getEnv("AGENT_HTTP_HOST", from: dotEnv) ?? "127.0.0.1"
        let port = Int(getEnv("AGENT_HTTP_PORT", from: dotEnv) ?? "") ?? 4242

        let agent = createAgent(options: AgentOptions(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            provider: useOpenAI ? .openai : .anthropic
        ))

        let server = AgentHTTPServer(
            agent: agent,
            host: host,
            port: port,
            authKey: "demo-secret-key",
            maxConcurrentRuns: 5
        )

        print("╔══════════════════════════════════════════════════════════════╗")
        print("║  AgentHTTPServer Example                                    ║")
        print("╚══════════════════════════════════════════════════════════════╝")
        print()
        print("Starting server on http://\(host):\(port)")
        print()
        print("Try these curl commands:")
        print()
        print("# Health check (no auth required)")
        print("  curl http://\(host):\(port)/v1/health")
        print()
        print("# Submit a new run")
        print("  curl -X POST http://\(host):\(port)/v1/runs \\")
        print("    -H 'Authorization: Bearer demo-secret-key' \\")
        print("    -H 'Content-Type: application/json' \\")
        print("    -d '{\"task\": \"List files in the current directory\"}'")
        print()
        print("# List all runs")
        print("  curl http://\(host):\(port)/v1/runs \\")
        print("    -H 'Authorization: Bearer demo-secret-key'")
        print()
        print("# Get run status (replace {run_id})")
        print("  curl http://\(host):\(port)/v1/runs/{run_id} \\")
        print("    -H 'Authorization: Bearer demo-secret-key'")
        print()
        print("# Stream run events via SSE")
        print("  curl -N http://\(host):\(port)/v1/runs/{run_id}/events \\")
        print("    -H 'Authorization: Bearer demo-secret-key'")
        print()

        try await server.start()
    }
}
