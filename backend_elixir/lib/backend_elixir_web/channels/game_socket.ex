defmodule BackendElixirWeb.GameSocket do
  use Phoenix.Socket

  channel "game:*", BackendElixirWeb.GameChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # Generate a unique player ID for each connection
    player_id = generate_player_id()
    {:ok, assign(socket, :player_id, player_id)}
  end

  @impl true
  def id(socket), do: "player:#{socket.assigns.player_id}"

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
