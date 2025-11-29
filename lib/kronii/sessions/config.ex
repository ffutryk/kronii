defmodule Kronii.Sessions.Config do
  alias Kronii.LLM.Config, as: LLMConfig

  defstruct assistant_name: "Assistant",
            system_prompt: nil,
            context_window: 20,
            llm_config: %LLMConfig{}

  @valid_keys [:assistant_name, :system_prompt, :context_window, :llm_config]

  @type t :: %__MODULE__{
          assistant_name: String.t(),
          system_prompt: String.t() | nil,
          context_window: pos_integer(),
          llm_config: LLMConfig.t()
        }

  def new(attrs \\ %{}) do
    do_update(%__MODULE__{}, %LLMConfig{}, attrs)
  end

  def patch(config, updates) do
    do_update(config, config.llm_config, updates)
  end

  defp do_update(base_config, base_llm, attrs) do
    attrs = Enum.into(attrs, %{})
    {llm_attrs, session_attrs} = Map.split(attrs, [:model, :temperature, :max_tokens])

    llm_config = update_llm(base_llm, llm_attrs)

    session_attrs
    |> Map.put(:llm_config, llm_config)
    |> prepare_attrs()
    |> then(&struct(base_config, &1))
  end

  defp update_llm(base_llm, llm_attrs) when map_size(llm_attrs) == 0,
    do: base_llm

  defp update_llm(%LLMConfig{} = _base, llm_attrs) when map_size(llm_attrs) > 0,
    do: LLMConfig.new(llm_attrs)

  defp update_llm(base_llm, llm_attrs),
    do: LLMConfig.patch(base_llm, llm_attrs)

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

  defp validate_field({:assistant_name, value})
       when not is_binary(value),
       do: raise(ArgumentError, ":assistant_name must be a string")

  defp validate_field({:system_prompt, value})
       when not is_binary(value) and not is_nil(value),
       do: raise(ArgumentError, ":system_prompt must be a string or nil")

  defp validate_field({:context_window, value})
       when not (is_integer(value) and value > 0),
       do: raise(ArgumentError, ":context_window must be a positive integer")

  defp validate_field({:llm_config, %LLMConfig{}}), do: :ok

  defp validate_field({:llm_config, _}),
    do: raise(ArgumentError, ":llm_config must be a %Kronii.LLM.Config{}")

  defp validate_field(_), do: :ok
end
