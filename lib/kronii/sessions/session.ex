defmodule Kronii.Sessions.Session do
  alias Kronii.Sessions.Config
  alias Kronii.Messages.Message

  defstruct [
    :id,
    :user_id,
    :source,
    :config,
    message_history: [],
    message_count: 0,
    summary: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          source: String.t(),
          message_history: [Message.t()],
          message_count: non_neg_integer(),
          summary: String.t() | nil,
          config: Config.t()
        }

  @spec new(String.t(), String.t()) :: t()
  @spec new(String.t(), String.t(), Config.t()) :: t()
  def new(user_id, source, config \\ Kronii.Sessions.Config.new()) do
    session = %__MODULE__{
      id: ExULID.ULID.generate(),
      user_id: user_id,
      source: source,
      config: config
    }

    validate_session(session)
    session
  end

  @spec add_message(t(), Message.t()) :: t()
  def add_message(%__MODULE__{} = session, %Message{} = message),
    do: %__MODULE__{
      session
      | message_history: [message | session.message_history],
        message_count: session.message_count + 1
    }

  @spec needs_summarization?(t()) :: boolean()
  def needs_summarization?(%__MODULE__{} = session),
    do: session.message_count >= session.config.context_window

  @spec patch_config(t(), keyword() | map()) :: t()
  def patch_config(%__MODULE__{} = session, updates) do
    %__MODULE__{session | config: Config.patch(session.config, updates)}
  end

  @spec apply_summary(t(), String.t(), DateTime.t()) :: t()
  def apply_summary(%__MODULE__{} = session, summary, %DateTime{} = timestamp) do
    filtered_history =
      Enum.take_while(session.message_history, &(not DateTime.before?(&1.timestamp, timestamp)))

    updated_session = %__MODULE__{
      session
      | message_history: filtered_history,
        message_count: length(filtered_history),
        summary: summary
    }

    validate_session(updated_session)
    updated_session
  end

  defp validate_session(%__MODULE__{} = session) do
    session
    |> Map.from_struct()
    |> Enum.each(&validate_field/1)
  end

  defp validate_field({:id, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":id must be a string")

  defp validate_field({:user_id, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":user_id must be a string")

  defp validate_field({:source, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":source must be a string")

  defp validate_field({:message_history, value})
       when not is_list(value),
       do: raise(ArgumentError, ":message_history must be a list")

  defp validate_field({:message_history, value})
       when is_list(value),
       do:
         unless(Enum.all?(value, &match?(%Message{}, &1)),
           do: raise(ArgumentError, ":message_history must be a list of Message structs")
         )

  defp validate_field({:message_count, value})
       when not is_integer(value) or value < 0,
       do: raise(ArgumentError, ":message_count must be a non-negative integer")

  defp validate_field({:summary, value})
       when not is_binary(value) and not is_nil(value),
       do: raise(ArgumentError, ":summary must be a string or nil")

  defp validate_field({:config, %Config{}}),
    do: :ok

  defp validate_field({:config, _}),
    do: raise(ArgumentError, ":config must be a Config struct")

  defp validate_field(_), do: :ok
end
