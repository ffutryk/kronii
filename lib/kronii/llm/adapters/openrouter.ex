defmodule Kronii.LLM.Adapters.OpenRouter do
  @behaviour Kronii.LLM.Adapter

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

    messages
    |> req_client(config, stream?)
    |> maybe_enable_stream(stream?, pid)
    |> Req.post()
    |> handle_response(stream?)
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

  defp handle_stream({:data, chunk}, {req, res}, pid)
       when is_binary(chunk),
       do: process_dataline(chunk, req, res, pid)

  defp handle_stream(_other, state, _pid), do: {:cont, state}

  defp process_dataline(dataline, req, res, pid) do
    {req, res} =
      dataline
      |> parse_dataline()
      |> Enum.map(&extract_fields/1)
      |> Enum.reject(&empty_chunk?/1)
      |> Enum.reduce({req, res}, fn fields, {req_acc, res_acc} ->
        {:cont, {req_next, res_next}} = process_chunk(fields, req_acc, res_acc, pid)
        {req_next, res_next}
      end)

    {:cont, {req, res}}
  end

  defp parse_dataline(dataline) when is_binary(dataline) do
    dataline
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.reject(&(&1 == "data: [DONE]"))
    |> Enum.map(&String.replace_prefix(&1, "data: ", ""))
  end

  defp extract_fields(json) when is_binary(json) do
    with {:ok, decoded} <- Jason.decode(json) do
      get_in(decoded, ["choices", Access.at(0)])
      |> do_extract_fields()
    else
      _ -> nil
    end
  end

  defp do_extract_fields(choice) do
    delta = Map.get(choice, "delta", %{})

    %{
      content: Map.get(delta, "content"),
      tool_calls: Map.get(delta, "tool_calls"),
      finish_reason: Map.get(choice, "finish_reason")
    }
  end

  defp process_chunk(%{content: content} = _fields, req, res, pid) do
    send(pid, {:chunk, content})

    acc = Req.Response.get_private(res, :chunks, [])
    res = Req.Response.put_private(res, :chunks, [content | acc])

    {:cont, {req, res}}
  end

  defp handle_response({:ok, %{status: 200, body: body}}, false) do
    %{"choices" => [%{"message" => %{"content" => content}} | _]} = body
    {:done, Message.assistant(content)}
  end

  defp handle_response({:ok, response} = _res, true) do
    content =
      response
      |> Req.Response.get_private(:chunks, [])
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {:done, Message.assistant(content)}
  end

  defp handle_response({:error, reason}, _stream?) do
    {:error, reason}
  end

  defp empty_chunk?(%{content: content, tool_calls: tool_calls}),
    do: is_nil(content) and is_nil(tool_calls)

  defp maybe_enable_stream(client, true, pid),
    do: Req.merge(client, into: &handle_stream(&1, &2, pid))

  defp maybe_enable_stream(client, false, _pid), do: client

  defp wrap_and_send(result, nil), do: result
  defp wrap_and_send(result, pid) when is_pid(pid), do: send(pid, result)

  defp get_api_key, do: Application.fetch_env!(:kronii, :openrouter_key)
end
