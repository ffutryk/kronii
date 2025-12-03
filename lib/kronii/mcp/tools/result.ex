defmodule Kronii.MCP.Tools.Result do
  @type status :: :ok | :error

  @type t :: %__MODULE__{
          id: String.t(),
          status: status(),
          result: map() | nil,
          error: String.t() | nil
        }

  defstruct [
    :id,
    :status,
    :result,
    :error
  ]
end
