defmodule BenchmarkPhoenixWeb.BenchChannel do
  use Phoenix.Channel

  @impl true
  def join("bench:" <> _topic, _params, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("broadcast", %{"payload" => payload}, socket) do
    broadcast!(socket, "broadcast", %{payload: payload})
    {:reply, :ok, socket}
  end

  def handle_in("broadcast", _params, socket) do
    broadcast!(socket, "broadcast", %{payload: %{}})
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{} = _msg, socket) do
    {:noreply, socket}
  end
end
