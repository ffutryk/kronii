defmodule Kronii.LLM.Adapter do
  alias Kronii.Messages.Message
  alias Kronii.MCP.Tool

  @type message :: %Message{}
  @type options :: [
          config: Kronii.LLM.Config.t(),
          pid: pid() | nil,
          stream?: boolean(),
          tools: [Tool.t()]
        ]

  @callback generate(messages :: [message], opts :: options) :: message()
end
