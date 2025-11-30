defmodule Kronii.MCP do
  use Supervisor

  alias Anubis.MCP. {Response, Error}

  @client Kronii.MCP.Client

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
    do: {Kronii.MCP.Client, name: name, transport: server_transport(server)}

  defp server_transport(%{transport: :stdio, command: command, args: args}),
    do: {:stdio, command: command, args: args}

  defp server_transport(%{transport: transport, base_url: base_url})
       when transport in [:streamable_http, :websocket, :sse],
       do: {transport, base_url: base_url}

  def list_tools() do
    with_client({:ok, []}, fn ->
      @client.list_tools()
    end)
  end

  def call_tool(name, opts) do
    with_client({:error, :not_found}, fn ->
      @client.call_tool(name, opts)
    end)
  end

  def list_resources() do
    with_client({:ok, []}, fn ->
      @client.list_resources()
    end)
  end

  def read_resource(resource) do
    with_client({:error, :not_found}, fn ->
      @client.read_resource(resource)
    end)
  end

  defp with_client(fallback, fun) when is_function(fun, 0) do
    case Process.whereis(@client) do
      nil -> fallback
      _pid -> fun.()
    end
  end
end
