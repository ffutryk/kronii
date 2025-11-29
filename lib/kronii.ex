defmodule Kronii do
  alias Kronii.Sessions.Supervisor
  alias Kronii.Sessions.Runtime
  alias Kronii.Messages.Message

  def create_session(source, initial_config_updates \\ %{}) do
    Kronii.Sessions.Supervisor.start_session(source, initial_config_updates)
  end

  def close_session(session_id), do: Supervisor.stop_session(session_id)

  def request_generation(session_id, username, content) do
    with_session(session_id, fn pid ->
      msg = Message.user(username, content)
      Runtime.generate(pid, msg)
      :ok
    end)
  end

  def cancel_generation(session_id) do
    with_session(session_id, fn pid ->
      Runtime.cancel_generation(pid)
      :ok
    end)
  end

  def patch_session_config(session_id, updates) do
    with_session(session_id, fn pid ->
      Runtime.patch_config(pid, updates)
      :ok
    end)
  end

  def notify_client(session_id, message) do
    IO.inspect({session_id, message}, label: "notify_client")
  end

  def with_session(session_id, fun) when is_binary(session_id) and is_function(fun, 1) do
    case Registry.lookup(Kronii.Sessions.Registry, session_id) do
      [{pid, _}] -> fun.(pid)
      [] -> {:error, :not_found}
    end
  end
end
