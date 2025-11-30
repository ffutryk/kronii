import Config

adapter =
  case System.get_env("LLM_PROVIDER") do
    "openrouter" -> Kronii.LLM.Adapters.OpenRouter
    _ -> Kronii.LLM.Adapters.OpenRouter
  end

config :kronii,
  http_port: 4000,
  llm_adapter: adapter,
  model: System.get_env("LLM_DEFAULT_MODEL"),
  openrouter_key: System.get_env("OPENROUTER_API_KEY"),
  mcp_servers: []
