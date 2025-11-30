defmodule Kronii.LLM.Config do
  defstruct model: nil,
            temperature: 1.0,
            max_tokens: nil

  @valid_keys [:model, :temperature, :max_tokens]

  @type t :: %__MODULE__{
          model: String.t(),
          temperature: float(),
          max_tokens: pos_integer() | nil
        }

  def new(attrs \\ %{}) do
    attrs
    |> prepare_attrs()
    |> drop_nil_values()
    |> maybe_put_default_model()
    |> then(&struct(__MODULE__, &1))
  end

  @spec patch(t(), keyword() | map()) :: t()
  def patch(%__MODULE__{} = config, updates) do
    updates
    |> prepare_attrs()
    |> drop_nil_values()
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

  defp maybe_put_default_model(attrs) do
    Map.put_new(attrs, :model, Application.get_env(:kronii, :model))
  end

  defp drop_nil_values(attrs) do
    Enum.reject(attrs, fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

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
