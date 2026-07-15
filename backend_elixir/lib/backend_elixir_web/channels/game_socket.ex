defmodule BackendElixirWeb.GameSocket do
  use Phoenix.Socket

  alias BackendElixir.IdGenerator

  channel "game:*", BackendElixirWeb.GameChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # Generate a unique player ID for each connection
    player_id = IdGenerator.generate_player_id()
    {:ok, assign(socket, :player_id, player_id)}
  end

  @impl true
  def id(socket), do: "player:#{socket.assigns.player_id}"
end
