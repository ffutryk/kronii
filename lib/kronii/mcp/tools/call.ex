defmodule Kronii.MCP.Tools.Call do
  @type t :: %__MODULE__{
          id: String.t(),
          tool: String.t(),
          args: map()
        }

  defstruct [
    :id,
    :tool,
    :args
  ]
end
