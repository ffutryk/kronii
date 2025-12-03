defmodule Kronii.MCP.Adapters.Anubis do
  @behaviour Kronii.MCP.Adapter
  use Supervisor

  alias Kronii.MCP.Adapters.Anubis.Client
  alias Kronii.MCP.Tool
  alias Kronii.MCP.Tools.{Call, Result}

  @impl true
  def child_spec() do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :supervisor
    }
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Application.get_env(:kronii, :mcp_servers, [])
    |> Enum.map(&server_spec/1)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp server_spec(%{name: name} = server),
    do: Supervisor.child_spec(module_spec(server), id: name)

  defp module_spec(%{name: name} = server),
    do: {Client, name: name, transport: server_transport(server)}

  defp server_transport(%{transport: :stdio, command: command, args: args}),
    do: {:stdio, command: command, args: args}

  defp server_transport(%{transport: transport, base_url: base_url})
       when transport in [:streamable_http, :websocket, :sse],
       do: {transport, base_url: base_url}

  @impl true
  def list_tools() do
    with_client({:ok, []}, fn ->
      fetch_server_tools()
    end)
  end

  @impl true
  def call_tool(%Call{} = call) do
    with_client(
      {:ok, %Result{id: call.id, status: :error, error: "No servers connected"}},
      fn -> do_call_tool(call) end
    )
  end

  defp fetch_server_tools() do
    case Client.list_tools() do
      {:ok, %Anubis.MCP.Response{result: %{"tools" => tools}}} ->
        {:ok, Enum.map(tools, &map_tool/1)}

      other ->
        {:error, inspect(other)}
    end
  end

  defp do_call_tool(%Call{id: id, tool: name, args: args}) do
    case Client.call_tool(name, args) do
      {:ok, %Anubis.MCP.Response{} = resp} ->
        {:ok, map_tool_call_response(id, resp)}

      {:error, err} ->
        {:ok, error_result(id, inspect(err))}
    end
  end

  defp map_tool_call_response(id, %Anubis.MCP.Response{
         is_error: false,
         result: result
       }) do
    %Result{id: id, status: :ok, result: normalize_result(result), error: nil}
  end

  defp map_tool_call_response(id, %Anubis.MCP.Response{
         is_error: true,
         result: %{"error" => error}
       }) do
    %Result{id: id, status: :error, result: nil, error: format_error(error)}
  end

  defp map_tool_call_response(id, %Anubis.MCP.Response{
         is_error: true,
         result: other
       }) do
    %Result{id: id, status: :error, result: nil, error: inspect(other)}
  end

  defp map_tool(%{"name" => name, "description" => desc, "inputSchema" => schema}) do
    %Tool{name: name, description: desc, parameters: schema}
  end

  defp normalize_result(%{"content" => content}) when is_list(content) do
    %{
      content: Enum.map(content, &normalize_content_item/1)
    }
  end

  defp normalize_result(other), do: other

  defp normalize_content_item(%{"type" => "text", "text" => text}), do: text
  defp normalize_content_item(%{"type" => type} = item), do: %{type: type, raw: item}
  defp normalize_content_item(other), do: other

  defp format_error(%{"message" => msg}), do: msg
  defp format_error(err), do: inspect(err)

  defp error_result(id, error) do
    %Result{id: id, status: :error, result: nil, error: error}
  end

  defp with_client(fallback, fun) do
    case Process.whereis(Client) do
      nil -> fallback
      _pid -> fun.()
    end
  end
end
