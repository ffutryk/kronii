defmodule Kronii.Sessions.Summarizer do
  alias Kronii.Messages.Message
  alias Kronii.LLM.OpenRouter
  alias Kronii.LLM.Config

  @max_tokens 550
  @default_user_name "User"
  @previous_summary_placeholder "<PREVIOUS_SUMMARY>"
  @transcript_placeholder "<TRANSCRIPT>"
  @max_tokens_placeholder "<MAX_TOKENS>"

  @raw_system_prompt """
  You are an assistant dedicated to generating high-quality summaries of conversation histories for use in a chatbot. Your task is to transform the provided dialogue into a concise, coherent narrative that preserves the essential information required to continue the interaction effectively. Focus on user intentions, preferences, decisions, and any tasks, topics, or requests that may influence the assistant's next response. Capture the meaning and context of the exchange rather than reciting turn-by-turn details. The summary should be written in clear, natural language and remain under #{@max_tokens_placeholder} tokens.
  """

  @raw_user_prompt """
  Please generate an updated conversation summary using the information below.

  Previous Summary:
  #{@previous_summary_placeholder}

  New Conversation Transcript:
  #{@transcript_placeholder}

  Instructions:
  - Integrate the new transcript into the previous summary.
  - Preserve only essential details needed for contextual continuity.
  - Update or refine user intentions, preferences, tasks, and relevant decisions.
  - Remove redundant or outdated information.
  - Maintain a concise, coherent narrative that aligns with the system's summarization rules.
  """

  def summarize(
        message_history,
        assistant_name,
        previous_summary \\ "N/A",
        pid \\ nil,
        config \\ nil
      ) do
    message =
      conversation_transcript(message_history, assistant_name)
      |> user_message(previous_summary)

    config =
      case config || Config.new() do
        %Config{max_tokens: nil} = cfg ->
          Config.patch(cfg, max_tokens: @max_tokens)

        cfg ->
          cfg
      end

    messages = [system_message(config.max_tokens), message]

    last_message = List.last(message_history)

    result = OpenRouter.generate(messages, config: config)
    handle_generation_result(result, pid, last_message.timestamp)
  end

  defp handle_generation_result({:done, %Message{content: content}}, nil, timestamp) do
    {:ok, content, timestamp}
  end

  defp handle_generation_result({:done, %Message{content: content}}, pid, timestamp)
       when is_pid(pid) do
    send(pid, {:summarization_done, content, timestamp})
    {:ok, content}
  end

  defp handle_generation_result({:error, reason}, nil, _) do
    {:error, reason}
  end

  defp handle_generation_result({:error, reason}, pid, _) when is_pid(pid) do
    send(pid, {:summarization_error, reason})
    {:error, reason}
  end

  defp user_message(conversation_transcript, previous_summary \\ "N/A") do
    prompt =
      @raw_user_prompt
      |> String.replace(@transcript_placeholder, conversation_transcript)
      |> String.replace(@previous_summary_placeholder, previous_summary)

    Message.user(prompt)
  end

  defp conversation_transcript(conversation, assistant_name) when is_list(conversation) do
    conversation
    |> Enum.map(&format_message(&1, assistant_name))
    |> IO.iodata_to_binary()
  end

  defp format_message(%Message{role: :assistant, content: content}, assistant_name),
    do: segment(assistant_name, content)

  defp format_message(%Message{role: :user, name: nil, content: content}, _),
    do: segment(@default_user_name, content)

  defp format_message(%Message{role: :user, name: name, content: content}, _),
    do: segment(name, content)

  defp segment(name, content), do: [name, ": ", content, "\n"]

  defp system_message(max_tokens) do
    prompt =
      String.replace(@raw_system_prompt, @max_tokens_placeholder, Integer.to_string(max_tokens))

    Message.system(prompt)
  end
end
