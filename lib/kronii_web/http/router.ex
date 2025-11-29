defmodule KroniiWeb.Http.Router do
  use Plug.Router

  alias KroniiWeb.Http.SessionController
  alias KroniiWeb.Http.Utils

  plug(Plug.Logger)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded, :multipart],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/sessions/:session_id/ws" do
    conn = Plug.Conn.fetch_query_params(conn)
    session_id = conn.params["session_id"]

    conn
    |> Plug.Conn.upgrade_adapter(
      :websocket,
      {KroniiWeb.Websocket.Handler, %{session_id: session_id}, %{}}
    )
  end

  post "/sessions" do
    SessionController.create(conn)
  end

  patch "/sessions/:session_id" do
    SessionController.patch(conn)
  end

  delete "/sessions/:session_id" do
    SessionController.delete(conn)
  end

  match _ do
    Utils.json_resp(conn, 404, %{error: "not_found"})
  end
end
