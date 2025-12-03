defmodule Kronii.MCP.Client do
  @behaviour Kronii.MCP.Adapter

  def child_spec(), do: adapter().child_spec()
  def list_tools(), do: adapter().list_tools()
  def call_tool(tool_call), do: adapter().call_tool(tool_call)
  defp adapter, do: Application.get_env(:kronii, :mcp_adapter)
end
