defmodule Kronii.Sessions.Session do
  alias Kronii.Sessions.Config

  defstruct [
    :id,
    :source,
    :config,
    summary: "N/A"
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          summary: String.t() | nil,
          config: Config.t()
        }

  @spec new(String.t()) :: t()
  @spec new(String.t(), Config.t()) :: t()
  def new(source, config \\ Kronii.Sessions.Config.new()) do
    session = %__MODULE__{
      id: ExULID.ULID.generate(),
      source: source,
      config: config
    }

    validate_session(session)
    session
  end

  @spec patch_config(t(), keyword() | map()) :: t()
  def patch_config(%__MODULE__{} = session, updates) do
    %__MODULE__{session | config: Config.patch(session.config, updates)}
  end

  @spec apply_summary(t(), String.t()) :: t()
  def apply_summary(%__MODULE__{} = session, summary) do
    updated_session = %__MODULE__{
      session
      | summary: summary
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

  defp validate_field({:source, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":source must be a string")

  defp validate_field({:summary, value})
       when not is_binary(value) and not is_nil(value),
       do: raise(ArgumentError, ":summary must be a string or nil")

  defp validate_field({:config, %Config{}}),
    do: :ok

  defp validate_field({:config, _}),
    do: raise(ArgumentError, ":config must be a Config struct")

  defp validate_field(_), do: :ok
end
