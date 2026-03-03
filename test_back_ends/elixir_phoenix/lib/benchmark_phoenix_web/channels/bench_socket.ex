defmodule BenchmarkPhoenixWeb.BenchSocket do
  use Phoenix.Socket

  channel "bench:*", BenchmarkPhoenixWeb.BenchChannel

  @impl true
  def connect(_params, socket, _info), do: {:ok, socket}
  @impl true
  def id(_socket), do: nil
end
