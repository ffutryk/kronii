defmodule Kronii.LLM.OpenRouter do
  alias Kronii.LLM.Config
  alias Kronii.Messages.Message

  @api_url "https://openrouter.ai/api/v1/chat/completions"

  def generate(messages, opts \\ [])

  def generate([], _opts), do: raise(ArgumentError, ":messages cannot be empty")

  def generate(messages, opts) when is_list(messages) do
    config = Keyword.get(opts, :config, Config.new())
    pid = Keyword.get(opts, :pid, nil)
    stream? = Keyword.get(opts, :stream?, false)

    if is_nil(pid) and stream?,
      do: raise(ArgumentError, ":pid cannot be nil when :stream? is true")

    client = req_client(messages, config, stream?) |> maybe_enable_stream(stream?, pid)

    do_request(client, on_success_handler(stream?))
    |> wrap_and_send(pid)
  end

  defp req_client(messages, config, stream?) do
    messages = map_messages(messages)

    Req.new(
      url: @api_url,
      method: :post,
      auth: {:bearer, get_api_key()},
      json: %{
        stream: stream?,
        messages: messages,
        model: config.model,
        max_tokens: config.max_tokens || nil,
        temperature: config.temperature
      }
    )
  end

  defp map_messages(messages) when is_list(messages), do: Enum.map(messages, &map_message/1)

  defp map_message(%Message{} = message) do
    %{
      "role" => message.role |> Atom.to_string(),
      "content" => message.content,
      "name" => message.name,
      "tool_calls" => message.tool_calls,
      "tool_call_id" => message.tool_call_id
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

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
    process_chunk(chunk, req, res, pid)
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

  defp maybe_enable_stream(client, true, pid),
    do: Req.merge(client, into: &handle_stream(&1, &2, pid))

  defp maybe_enable_stream(client, false, _pid), do: client

  defp wrap_and_send(result, nil), do: result
  defp wrap_and_send(result, pid) when is_pid(pid), do: send(pid, result)

  defp get_api_key, do: Application.fetch_env!(:kronii, :openrouter_key)
end
