defmodule Kronii.Sessions.Supervisor do
  use DynamicSupervisor

  alias Kronii.Sessions.Session
  alias Kronii.Sessions.Runtime

  @registry_name Kronii.Sessions.Registry
  @supervisor_name __MODULE__

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: @supervisor_name)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(source, websocket) do
    session = Session.new(source)

    spec = build_child_spec(session, websocket)

    case DynamicSupervisor.start_child(@supervisor_name, spec) do
      {:ok, pid} -> {:ok, pid, session}
      {:error, reason} -> {:error, reason}
    end
  end

  def stop_session(session_id) do
    case Registry.lookup(@registry_name, session_id) do
      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(@supervisor_name, pid) do
          :ok -> :ok
          {:error, _} = err -> err
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp build_child_spec(session, websocket) do
    %{
      id: {:session, session.id},
      start: {
        Runtime,
        :start_link,
        [
          [
            session: session,
            websocket: websocket,
            name: via_tuple(session)
          ]
        ]
      }
    }
  end

  defp via_tuple(session), do: {:via, Registry, {@registry_name, session.id}}

  def registry_name, do: @registry_name
end
