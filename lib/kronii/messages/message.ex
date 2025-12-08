defmodule Kronii.Messages.SystemMessage do
  @enforce_keys [:role, :content]
  defstruct [:role, :content]

  @type t :: %__MODULE__{
          role: :system,
          content: String.t()
        }
end

defmodule Kronii.Messages.UserMessage do
  @enforce_keys [:role, :name, :content]
  defstruct [:role, :name, :content]

  @type t :: %__MODULE__{
          role: :user,
          name: String.t(),
          content: String.t()
        }
end

defmodule Kronii.Messages.AssistantMessage do
  @enforce_keys [:role, :content]
  defstruct [:role, :name, :content, :tool_calls]

  @type t :: %__MODULE__{
          role: :assistant,
          name: String.t() | nil,
          content: String.t(),
          tool_calls: list() | nil
        }
end

defmodule Kronii.Messages do
  alias Kronii.Messages.{SystemMessage, UserMessage, AssistantMessage}

  @type t ::
          SystemMessage.t()
          | UserMessage.t()
          | AssistantMessage.t()
end

defmodule Kronii.Messages.MessageFactory do
  alias Kronii.Messages.{SystemMessage, UserMessage, AssistantMessage}

  def system(content) do
    %SystemMessage{role: :system, content: content}
  end

  def user(name, content) do
    %UserMessage{role: :user, name: name, content: content}
  end

  def assistant(name \\ nil, content, tool_calls \\ nil) do
    %AssistantMessage{
      role: :assistant,
      name: name,
      content: content,
      tool_calls: tool_calls
    }
  end
end
