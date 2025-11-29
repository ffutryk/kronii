defmodule KroniiWeb.Http.SessionController do
  alias KroniiWeb.Http.Utils

  def create(%Plug.Conn{params: params} = conn) do
    initial_config_updates = Utils.sanitize_config(params)
    source = request_source(conn)

    with {:ok, _pid, session} <- Kronii.create_session(source, initial_config_updates) do
      Utils.json_resp(conn, 201, %{id: session.id})
    else
      {:error, reason} ->
        Utils.json_resp(conn, 500, %{error: to_string(reason)})
    end
  end

  def patch(%Plug.Conn{params: params} = conn) do
    session_id = conn.params["session_id"]

    config = Utils.sanitize_config(params)

    case Kronii.patch_session_config(session_id, config) do
      :ok -> Utils.json_resp(conn, 200, %{status: "ok"})
      {:error, :not_found} -> Utils.json_resp(conn, 404, %{error: "session_not_found"})
      {:error, reason} -> Utils.json_resp(conn, 500, %{error: to_string(reason)})
    end
  end

  def delete(conn) do
    session_id = conn.params["session_id"]

    case Kronii.close_session(session_id) do
      :ok -> Utils.json_resp(conn, 200, %{status: "closed"})
      {:error, :not_found} -> Utils.json_resp(conn, 404, %{error: "session_not_found"})
      {:error, reason} -> Utils.json_resp(conn, 500, %{error: to_string(reason)})
    end
  end

  defp request_source(%Plug.Conn{body_params: body_params}) do
    (body_params || %{})
    |> Map.get("source", "http")
  end
end
