import Config

llm_adapter =
  case System.get_env("LLM_PROVIDER") do
    "openrouter" -> Kronii.LLM.Adapters.OpenRouter
    _ -> Kronii.LLM.Adapters.OpenRouter
  end

mcp_adapter =
  case System.get_env("MCP") do
    "anubis" -> Kronii.MCP.Adapters.Anubis
    _ -> Kronii.MCP.Adapters.Anubis
  end

config :kronii,
  http_port: 4000,
  llm_adapter: llm_adapter,
  mcp_adapter: mcp_adapter,
  model: System.get_env("LLM_DEFAULT_MODEL"),
  openrouter_key: System.get_env("OPENROUTER_API_KEY"),
  mcp_servers: []
