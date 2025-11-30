defmodule Kronii.LLM.Adapter do
  alias Kronii.Messages.Message

  @type message :: %Message{}
  @type available_options :: :config | :pid | :stream?
  @type option :: {available_options(), any()}
  @type options :: [option]

  @callback generate(messages :: [message], opts :: options) :: message()
end
