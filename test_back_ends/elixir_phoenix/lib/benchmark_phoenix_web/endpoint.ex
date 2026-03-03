defmodule BenchmarkPhoenixWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :benchmark_phoenix

  socket "/ws", BenchmarkPhoenixWeb.BenchSocket,
    websocket: [check_origin: false, compress: true],
    longpoll: false

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug BenchmarkPhoenixWeb.Router
end
