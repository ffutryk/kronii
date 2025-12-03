defmodule Kronii.MCP.Adapter do
  alias Kronii.MCP.Tool
  alias Kronii.MCP.Tools.{Call, Result}

  @callback child_spec() :: Supervisor.child_spec()

  @callback list_tools() ::
              {:ok, [Tool.t()]} | {:error, term()}

  @callback call_tool(Call.t()) ::
              {:ok, Result.t()} | {:error, term()}
end
