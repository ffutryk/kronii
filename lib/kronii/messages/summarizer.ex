defmodule Kronii.Messages.Summarizer do
  alias Kronii.Messages.{UserMessage, AssistantMessage, MessageFactory}
  alias Kronii.LLM.{Client, Config}

  @max_tokens 550
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
        previous_summary,
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

    case Client.generate(messages, config: config) do
      {:done, %AssistantMessage{content: content}} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp user_message(conversation_transcript, previous_summary) do
    prompt =
      @raw_user_prompt
      |> String.replace(@transcript_placeholder, conversation_transcript)
      |> String.replace(@previous_summary_placeholder, previous_summary)

    MessageFactory.user("user", prompt)
  end

  defp conversation_transcript(conversation, assistant_name) when is_list(conversation) do
    conversation
    |> Enum.map(&format_message(&1, assistant_name))
    |> IO.iodata_to_binary()
  end

  defp format_message(%AssistantMessage{content: content}, assistant_name),
    do: segment(assistant_name, content)

  defp format_message(%UserMessage{name: name, content: content}, _),
    do: segment(name, content)

  defp segment(name, content), do: [name, ": ", content, "\n"]

  defp system_message(max_tokens) do
    prompt =
      String.replace(@raw_system_prompt, @max_tokens_placeholder, Integer.to_string(max_tokens))

    MessageFactory.system(prompt)
  end
end
