defmodule Kronii.LLM.Client do
  @behaviour Kronii.LLM.Adapter

  def generate(messages, opts \\ []), do: adapter().generate(messages, opts)
  defp adapter, do: Application.get_env(:kronii, :llm_adapter)
end
