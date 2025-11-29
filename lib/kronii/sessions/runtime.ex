defmodule Kronii.Sessions.Runtime do
  @behaviour :gen_statem

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    session = Keyword.fetch!(opts, :session)
    websocket = Keyword.fetch!(opts, :websocket)

    data = %{session: session, websocket: websocket}

    :gen_statem.start_link(name, __MODULE__, data, [])
  end

  # Callbacks

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @impl :gen_statem
  def init(%{session: session, websocket: websocket}) do
    data = %{
      session: session,
      websocket: websocket
    }

    {:ok, :active, data}
  end
end
