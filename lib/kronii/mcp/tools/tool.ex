defmodule Kronii.MCP.Tool do
  @type json_schema :: map()

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          parameters: json_schema
        }

  defstruct [
    :name,
    :description,
    :parameters
  ]
end
