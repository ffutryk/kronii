defmodule Kronii.Sessions.Config do
  defstruct system_prompt: nil,
            context_window: 20,
            model: Application.compile_env!(:kronii, :default_model),
            temperature: 1.0,
            max_tokens: nil

  @valid_keys [:system_prompt, :context_window, :model, :temperature, :max_tokens]

  @type t :: %__MODULE__{
          system_prompt: String.t() | nil,
          context_window: pos_integer(),
          model: String.t(),
          temperature: float(),
          max_tokens: pos_integer() | nil
        }

  def new(attrs \\ %{}) do
    attrs
    |> prepare_attrs()
    |> then(&struct(__MODULE__, &1))
  end

  @spec patch(t(), keyword()) :: t()
  def patch(%__MODULE__{} = config, updates) do
    updates
    |> prepare_attrs
    |> then(&struct(config, &1))
  end

  defp prepare_attrs(attrs) do
    attrs
    |> Enum.into(%{})
    |> Map.take(@valid_keys)
    |> validate_config()
  end

  defp validate_config(config) do
    Enum.each(config, &validate_field/1)
    config
  end

  defp validate_field({:system_prompt, value})
       when not is_binary(value) and not is_nil(value),
       do: raise(ArgumentError, ":system_prompt must be a string or nil")

  defp validate_field({:context_window, value})
       when not (is_integer(value) and value > 0),
       do: raise(ArgumentError, ":context_window must be a positive integer")

  defp validate_field({:model, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":model must be a string")

  defp validate_field({:temperature, value})
       when not is_number(value) or value < 0 or value > 2,
       do: raise(ArgumentError, ":temperature must be a number between 0 and 2")

  defp validate_field({:max_tokens, value})
       when not (is_integer(value) and value > 0) and not is_nil(value),
       do: raise(ArgumentError, ":max_tokens must be a positive integer or nil")

  defp validate_field(_), do: :ok
end
