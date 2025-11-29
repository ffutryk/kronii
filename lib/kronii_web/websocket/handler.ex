defmodule KroniiWeb.Websocket.Handler do
  @behaviour :cowboy_websocket

  @impl true
  def init(req, _opts) do
    session_id = :cowboy_req.binding(:session_id, req)

    if session_id == nil do
      {:ok, req} |> :cowboy_req.reply(400, %{}, "Missing session_id")
    else
      state = %{session_id: session_id}

      {:cowboy_websocket, req, state, %{idle_timeout: 60_000}}
    end
  end

  @impl true
  def websocket_init(%{session_id: session_id} = state) do
    Kronii.with_session(session_id, fn _pid ->
      Registry.register(KroniiWeb.Sessions.Socket, session_id, nil)
    end)

    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, msg}, %{session_id: session_id} = state) do
    case Jason.decode(msg) do
      {:ok, %{"action" => action} = payload} ->
        case action_to_handler(action) do
          {:ok, handler} -> handler.(session_id, payload, state)
          :error -> send_unknown_action(state)
        end

      _ ->
        {:reply, {:text, error_json("invalid_json")}, state}
    end
  end

  @impl true
  def websocket_handle(_msg, state) do
    {:ok, state}
  end

  @impl true
  def websocket_info({:notify, json}, state) do
    {:reply, {:text, json}, state}
  end

  @impl true
  def websocket_info(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _req, %{session_id: session_id}) do
    Registry.unregister(KroniiWeb.Sessions.Socket, session_id)
    :ok
  end

  defp action_to_handler("generation.start"), do: {:ok, &on_generation_request/3}
  defp action_to_handler("generation.cancel"), do: {:ok, &on_generation_cancel/3}
  defp action_to_handler(_unknown), do: :error

  defp send_unknown_action(state) do
    {:reply, {:text, error_json("unknown_action")}, state}
  end

  defp on_generation_request(session_id, payload, state) do
    username = Map.get(payload, "username", "User")
    content = Map.get(payload, "content", "...")

    case Kronii.request_generation(session_id, username, content) do
      :ok -> {:ok, state}
      {:error, reason} -> {:reply, {:text, error_json(reason)}, state}
    end
  end

  defp on_generation_cancel(session_id, _payload, state) do
    case Kronii.cancel_generation(session_id) do
      :ok -> {:ok, state}
      {:error, reason} -> {:reply, {:text, error_json(reason)}, state}
    end
  end

  defp error_json(reason) do
    Jason.encode!(%{type: "error", reason: reason})
  end
end
