defmodule Kronii.Sessions.Runtime do
  @behaviour :gen_statem

  alias Kronii.LLM.Client
  alias Kronii.Sessions.{Session, Summarizer}
  alias Kronii.Messages.Message

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    session = Keyword.fetch!(opts, :session)

    data = %{session: session}

    :gen_statem.start_link(name, __MODULE__, data, [])
  end

  def cancel_generation(server), do: :gen_statem.call(server, :cancel)
  def close(server), do: :gen_statem.call(server, :close)

  def generate(server, %Message{} = message),
    do: :gen_statem.cast(server, {:generate, message})

  def patch_config(server, updates) when is_list(updates) or is_map(updates),
    do: :gen_statem.cast(server, {:patch_config, updates})

  # Callbacks

  @impl :gen_statem
  def callback_mode(), do: :handle_event_function

  @impl :gen_statem
  def init(%{session: session}) do
    Process.flag(:trap_exit, true)

    data = %{
      session: session,
      tasks: %{
        generation: nil,
        summarization: nil
      },
      gen_id: nil
    }

    {:ok, :active, data}
  end

  def handle_event(:info, {:EXIT, pid, reason}, _state, data) do
    cond do
      pid == data.tasks.generation and reason not in [:normal, :shutdown] ->
        notify(data, {:generation_error, data.gen_id, reason})

        {:next_state, :active, stop_generation_task(data)}

      pid == data.tasks.summarization and reason not in [:normal, :shutdown] ->
        {:keep_state, stop_summarization_task(data)}

      true ->
        :keep_state_and_data
    end
  end

  @impl :gen_statem
  def handle_event(:cast, {:patch_config, updates}, _state, data)
      when is_list(updates) or is_map(updates) do
    updated_session = Session.patch_config(data.session, updates)
    data = put_session(data, updated_session)
    {:keep_state, data}
  end

  @impl :gen_statem
  def handle_event(:cast, {:generate, message}, state, data) when state in [:active, :idle] do
    new_session = Session.add_message(data.session, message)
    gen_id = new_gen_id()

    data =
      data
      |> put_session(new_session)
      |> put_gen_id(gen_id)
      |> start_generation_task()

    notify(data, {:generation_start, gen_id})

    {:next_state, :thinking, data}
  end

  @impl :gen_statem
  def handle_event(:info, {:chunk, chunk}, state, data) when state in [:thinking, :streaming] do
    notify(data, {:generation_chunk, data.gen_id, chunk})

    case state do
      :thinking -> {:next_state, :streaming, data}
      :streaming -> :keep_state_and_data
    end
  end

  @impl :gen_statem
  def handle_event(:info, {:done, message}, :streaming, data) do
    new_session = Session.add_message(data.session, message)
    gen_id = data.gen_id

    data =
      data
      |> put_session(new_session)
      |> stop_generation_task()
      |> clear_gen_id()
      |> maybe_summarize()

    notify(data, {:generation_complete, gen_id})

    {:next_state, :active, data}
  end

  @impl :gen_statem
  def handle_event({:call, from}, :cancel, state, data) when state in [:thinking, :streaming] do
    if pid = data.tasks.generation do
      Process.exit(pid, :shutdown)
    end

    :gen_statem.reply(from, :ok)

    gen_id = data.gen_id
    data = data |> stop_generation_task() |> clear_gen_id()

    notify(data, {:generation_cancelled, gen_id})

    {:next_state, :active, data}
  end

  @impl :gen_statem
  def handle_event(:info, {:summarization_done, summary, timestamp}, _state, data) do
    new_session = Session.apply_summary(data.session, summary, timestamp)

    data =
      data
      |> put_session(new_session)
      |> stop_summarization_task()

    {:keep_state, data}
  end

  @impl :gen_statem
  def handle_event(:info, {:summarization_error, _reason}, _state, data) do
    data =
      data
      |> stop_summarization_task()

    {:keep_state, data}
  end

  @impl :gen_statem
  def handle_event(:info, {:error, reason}, state, data) when state in [:thinking, :streaming] do
    notify(data, {:generation_error, data.gen_id, reason})

    data = data |> stop_generation_task() |> clear_gen_id()

    {:next_state, :active, data}
  end

  @impl :gen_statem
  def handle_event({:call, from}, :close, _state, data) do
    if is_pid(data.tasks.generation), do: Process.exit(data.tasks.generation, :shutdown)
    if is_pid(data.tasks.summarization), do: Process.exit(data.tasks.summarization, :shutdown)

    :gen_statem.reply(from, :ok)
    {:stop, :normal}
  end

  @impl :gen_statem
  def handle_event({:call, from}, _event, _state, _data) do
    :gen_statem.reply(from, {:error, :invalid_state})
    :keep_state_and_data
  end

  defp start_generation_task(data) do
    server_pid = self()
    session = data.session
    messages = Enum.reverse(session.message_history)

    {:ok, task_pid} =
      Task.start_link(fn ->
        Client.generate(messages,
          config: session.config.llm_config,
          pid: server_pid,
          stream?: true
        )
      end)

    put_generation_task(data, task_pid)
  end

  defp maybe_summarize(data) do
    cond do
      Session.needs_summarization?(data.session) and is_nil(data.tasks.summarization) ->
        start_summarization_task(data)

      true ->
        data
    end
  end

  defp start_summarization_task(data) do
    server_pid = self()
    session = data.session

    {:ok, task_pid} =
      Task.start_link(fn ->
        Summarizer.summarize(
          Enum.reverse(session.message_history),
          session.config.assistant_name,
          session.summary,
          server_pid,
          session.config.llm_config
        )
      end)

    put_summarization_task(data, task_pid)
  end

  defp notify(%{session: session}, msg), do: Kronii.notify_client(session.id, event_to_map(msg))

  defp event_to_map({:generation_start, gen_id}) do
    %{type: "generation_start", gen_id: gen_id}
  end

  defp event_to_map({:generation_chunk, gen_id, chunk}) do
    %{type: "generation_chunk", gen_id: gen_id, chunk: chunk}
  end

  defp event_to_map({:generation_complete, gen_id}) do
    %{type: "generation_complete", gen_id: gen_id}
  end

  defp event_to_map({:generation_cancelled, gen_id}) do
    %{type: "generation_cancelled", gen_id: gen_id}
  end

  defp event_to_map({:generation_error, gen_id, reason}) do
    %{type: "generation_error", gen_id: gen_id, reason: reason}
  end

  defp stop_summarization_task(data), do: put_task(data, :summarization, nil)

  defp put_summarization_task(data, task_pid), do: put_task(data, :summarization, task_pid)

  defp stop_generation_task(data), do: put_task(data, :generation, nil)

  defp put_generation_task(data, task_pid), do: put_task(data, :generation, task_pid)

  defp put_session(data, session), do: update_data(data, :session, session)

  defp put_gen_id(data, gen_id), do: update_data(data, :gen_id, gen_id)

  defp clear_gen_id(data), do: update_data(data, :gen_id, nil)

  defp update_data(data, key, value), do: Map.put(data, key, value)

  defp new_gen_id, do: ExULID.ULID.generate()

  defp put_task(data, key, value) do
    updated_tasks = Map.put(data.tasks, key, value)
    update_data(data, :tasks, updated_tasks)
  end
end
