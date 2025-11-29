defmodule KroniiWeb.Http.Utils do
  import Plug.Conn

  @valid_keys ~w(assistant_name system_prompt context_window llm_config model temperature max_tokens)

  def json_resp(conn, status, map) when is_map(map) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(map))
  end

  def sanitize_config(params) do
    params |> Map.take(@valid_keys) |> map_to_atom_keys()
  end

  defp map_to_atom_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      {String.to_atom(k), v}
    end
  end
end
