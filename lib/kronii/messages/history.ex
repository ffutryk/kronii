defmodule Kronii.Messages.History do
  use GenServer

  alias Kronii.Messages
  alias Kronii.Messages.Summarizer

  # Client

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts)

  @spec add(pid(), Kronii.Messages.t()) :: :ok
  def add(pid, message) when is_pid(pid),
    do: GenServer.cast(pid, {:add, message})

  @spec add(pid(), integer()) :: list(Messages.t())
  def most_recent(pid, n) when is_pid(pid), do: GenServer.call(pid, {:most_recent, n})

  @spec maybe_summarize(pid(), pos_integer(), keyword()) :: :accepted | :skipped
  def maybe_summarize(pid, context_size, opts \\ []) when is_pid(pid),
    do: GenServer.call(pid, {:summarize, context_size, opts})

  # Callbacks

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    table = :ets.new(table_name(session_id), [:ordered_set, :private])

    {:ok, %{table: table, latest_summary: "N/A", summarizing?: false}}
  end

  @impl true
  def handle_cast({:add, message}, %{table: table} = state) do
    :ets.insert(table, {get_key(), message})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:summary_ready, summary, cutoff_ts, caller}, %{table: table} = state) do
    delete_before(table, :ets.first(table), cutoff_ts)
    send(caller, {:summarized, summary})
    {:noreply, %{state | latest_summary: summary, summarizing?: false}}
  end

  @impl true
  def handle_cast(:summary_failed, state) do
    {:noreply, %{state | summarizing?: false}}
  end

  @impl true
  def handle_call(
        {:summarize, context_size, opts},
        {caller, _ref},
        %{table: table, summarizing?: summarizing?} = state
      ) do
    cond do
      summarizing? ->
        {:reply, :skipped, state}

      count(table) < context_size ->
        {:reply, :skipped, state}

      true ->
        msgs = n_most_recent(table, context_size)
        summary_time = System.os_time(:microsecond)
        assistant_name = Keyword.get(opts, :assistant_name)
        config = Keyword.get(opts, :llm_config)
        latest_summary = state.latest_summary
        history_pid = self()

        {:ok, _task_pid} =
          Task.start(fn ->
            case Summarizer.summarize(msgs, assistant_name, latest_summary, config) do
              {:ok, summary} ->
                GenServer.cast(history_pid, {:summary_ready, summary, summary_time, caller})

              {:error, reason} ->
                send(caller, {:error, reason})
                GenServer.cast(history_pid, :summary_failed)
            end
          end)

        {:reply, :accepted, %{state | summarizing?: true}}
    end
  end

  @impl true
  def handle_call(
        {:most_recent, n},
        _from,
        %{table: table} = state
      ) do
    messages = n_most_recent(table, n)
    {:reply, {:ok, messages}, state}
  end

  defp n_most_recent(table, n) do
    table
    |> :ets.last()
    |> walk_back(table, n, [])
  end

  defp walk_back(:"$end_of_table", _table, _n, acc), do: acc

  defp walk_back(_key, _table, 0, acc), do: acc

  defp walk_back(key, table, n, acc) do
    [{_k, msg}] = :ets.lookup(table, key)
    prev = :ets.prev(table, key)
    walk_back(prev, table, n - 1, [msg | acc])
  end

  defp delete_before(_table, :"$end_of_table", _), do: :ok

  defp delete_before(table, key, cutoff) when key < cutoff do
    next = :ets.next(table, key)
    :ets.delete(table, key)

    delete_before(table, next, cutoff)
  end

  defp delete_before(_table, _key, _cutoff), do: :ok

  defp count(table), do: :ets.info(table, :size)
  defp table_name(session_id), do: :"history_#{session_id}"

  defp get_key(),
    do: {System.os_time(:microsecond), :erlang.unique_integer([:monotonic, :positive])}
end
