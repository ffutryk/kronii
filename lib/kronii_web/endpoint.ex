defmodule KroniiWeb.Endpoint do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    port = Application.get_env(:kronii, :http_port, 4000)

    children = [
      {Plug.Cowboy, scheme: :http, plug: KroniiWeb.Http.Router, options: [port: port]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
