defmodule Kronii do
  def notify_client(session_id, message) do
    IO.inspect({session_id, message}, label: "notify_client")
  end
end
