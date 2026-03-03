defmodule BenchmarkPhoenix.Repo do
  use Postgrex, otp_app: :benchmark_phoenix, name: __MODULE__

  def child_spec(opts) do
    config = Application.get_env(:benchmark_phoenix, __MODULE__, [])
    opts = Keyword.merge(config, opts)
    %{
      id: __MODULE__,
      start: {Postgrex, :start_link, [opts ++ [name: __MODULE__]]},
      type: :worker
    }
  end

  def query!(sql, params \\ []) do
    Postgrex.query!(__MODULE__, sql, params)
  end
end
