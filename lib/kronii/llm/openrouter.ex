defmodule Kronii.LLM.OpenRouter do
  alias Kronii.LLM.Config
  alias Kronii.Messages.Message

  @api_url "https://openrouter.ai/api/v1/chat/completions"

  def generate(messages, config \\ Config.new(), pid, stream? \\ false) when is_list(messages) do
    mapped_messages = map_messages(messages)

    client =
      build_req_client()
      |> Req.merge(json: build_request_body(mapped_messages, config, stream?))
      |> maybe_add_stream_handler(stream?, pid)

    result = do_request(client, on_success_handler(stream?))
    send(pid, result)
  end

  defp build_req_client do
    Req.new(
      url: @api_url,
      method: :post,
      auth: {:bearer, get_api_key()}
    )
  end

  defp build_request_body(messages, %Config{} = config, stream?) do
    %{
      model: config.model,
      messages: messages,
      temperature: config.temperature
    }
    |> maybe_put(:max_tokens, config.max_tokens)
    |> maybe_put_stream(stream?)
  end

  defp maybe_add_stream_handler(client, true, pid),
    do: Req.merge(client, into: &handle_stream(&1, &2, pid))

  defp maybe_add_stream_handler(client, false, _pid), do: client

  defp map_messages(messages) when is_list(messages), do: Enum.map(messages, &map_message/1)

  defp map_message(%Message{role: :tool} = message) do
    %{
      role: "tool",
      content: message.content,
      tool_call_id: message.tool_call_id
    }
    |> maybe_put(:name, message.name)
  end

  defp map_message(%Message{} = message) do
    %{
      role: Atom.to_string(message.role),
      content: message.content
    }
    |> maybe_put(:name, message.name)
  end

  defp get_api_key, do: Application.fetch_env!(:kronii, :openrouter_key)

  defp do_request(client, on_success) when is_function(on_success, 1) do
    case Req.post(client) do
      {:ok, %{status: 200} = res} ->
        on_success.(res)

      {:ok, %{status: status, body: body}} ->
        {:error, {:httperror, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp on_success_handler(true), do: &on_success_stream/1
  defp on_success_handler(false), do: &on_success_non_stream/1

  defp on_success_stream(res) do
    content =
      Req.Response.get_private(res, :accumulated_chunks, [])
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {:done, Message.assistant(content)}
  end

  defp handle_stream({:data, chunk}, {req, res}, pid) when is_binary(chunk) do
    if cancelled?() do
      send(pid, {:cancelled})
      {:halt, {req, res}}
    else
      process_chunk(chunk, req, res, pid)
    end
  end

  defp handle_stream(_other, state, _pid), do: {:cont, state}

  defp process_chunk(chunk, req, res, pid) do
    contents =
      chunk
      |> parse_chunk()
      |> Enum.map(&extract_content/1)
      |> Enum.reject(&is_nil/1)

    if contents == [] do
      {:cont, {req, res}}
    else
      Enum.each(contents, &send(pid, {:chunk, &1}))

      acc = Req.Response.get_private(res, :accumulated_chunks, [])
      updated_res = Req.Response.put_private(res, :accumulated_chunks, [contents | acc])

      {:cont, {req, updated_res}}
    end
  end

  defp parse_chunk(chunk) when is_binary(chunk) do
    for line <- String.split(chunk, "\n", trim: true),
        String.starts_with?(line, "data: "),
        line != "data: [DONE]" do
      String.replace_prefix(line, "data: ", "")
    end
  end

  defp extract_content(json) when is_binary(json) do
    with {:ok, decoded} <- Jason.decode(json),
         content when is_binary(content) and content != "" <-
           get_in(decoded, ["choices", Access.at(0), "delta", "content"]) do
      content
    else
      _ -> nil
    end
  end

  defp extract_content(_), do: nil

  defp cancelled? do
    receive do
      :cancel -> true
    after
      0 -> false
    end
  end

  defp on_success_non_stream(%{body: body}) do
    case handle_response(body) do
      {:ok, message} -> {:done, message}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_response(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    {:ok, Message.assistant(content)}
  end

  defp handle_response(other), do: {:error, {:unexpected_response, other}}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_stream(map, true), do: Map.put(map, :stream, true)
  defp maybe_put_stream(map, false), do: map
end
