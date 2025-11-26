defmodule Kronii.Messages.Message do
  defstruct [
    :role,
    :content,
    :name,
    :timestamp,
    :tool_calls,
    :tool_call_id
  ]

  @valid_roles [:user, :assistant, :system, :tool]

  @type role :: :user | :assistant | :system | :tool

  @type t :: %__MODULE__{
          role: role(),
          content: String.t() | map(),
          name: String.t() | nil,
          timestamp: DateTime.t(),
          tool_calls: list(map()) | nil,
          tool_call_id: String.t() | nil
        }

  @spec new(role(), String.t() | map(), String.t() | nil) :: t()
  def new(role, content, name \\ nil) do
    message = %__MODULE__{
      role: role,
      content: content,
      name: name,
      timestamp: DateTime.utc_now()
    }

    validate_message(message)
    message
  end

  @spec system(String.t()) :: t()
  def system(content), do: new(:system, content)

  @spec user(String.t(), String.t()) :: t()
  def user(name, content), do: new(:user, content, name)

  @spec assistant(String.t() | map()) :: t()
  def assistant(content), do: new(:assistant, content)

  defp validate_message(%__MODULE__{} = message) do
    message
    |> Map.from_struct()
    |> Enum.each(&validate_field/1)
  end

  defp validate_field({:role, value})
       when not is_nil(value) and value not in @valid_roles,
       do: raise(ArgumentError, ":role must be one of #{inspect(@valid_roles)} or nil")

  defp validate_field({:content, value})
       when is_nil(value) and not is_binary(value) and not is_map(value),
       do: raise(ArgumentError, ":content must be a string or map")

  defp validate_field({:name, value})
       when not is_nil(value) and not is_binary(value),
       do: raise(ArgumentError, ":name must be a string or nil")

  defp validate_field({:timestamp, %DateTime{}}), do: :ok

  defp validate_field({:timestamp, _}),
    do: raise(ArgumentError, ":timestamp must be a DateTime struct")

  defp validate_field({:tool_calls, value})
       when not is_nil(value) and not is_list(value),
       do: raise(ArgumentError, ":tool_calls must be a list or nil")

  defp validate_field({:tool_calls, list}) when is_list(list) do
    unless Enum.all?(list, &is_map/1),
      do: raise(ArgumentError, ":tool_calls must be a list of maps")
  end

  defp validate_field({:tool_call_id, value})
       when not is_nil(value) and not is_binary(value),
       do: raise(ArgumentError, ":tool_call_id must be a string or nil")

  defp validate_field(_), do: :ok
end
