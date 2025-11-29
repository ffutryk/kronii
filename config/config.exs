import Config

config :kronii,
  http_port: 4000,
  default_model: System.fetch_env!("LLM_DEFAULT_MODEL"),
  openrouter_key: System.fetch_env!("OPENROUTER_API_KEY")
