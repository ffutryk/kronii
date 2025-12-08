defmodule Kronii.LLM.Adapter do
  alias Kronii.Messages
  alias Kronii.MCP.Tool

  @type message :: list(Messages.t())
  @type options :: [
          config: Kronii.LLM.Config.t(),
          pid: pid() | nil,
          stream?: boolean(),
          tools: [Tool.t()]
        ]

  @callback generate(messages :: [message], opts :: options) :: message()
end
