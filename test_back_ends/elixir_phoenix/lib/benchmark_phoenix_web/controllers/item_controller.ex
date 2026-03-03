defmodule BenchmarkPhoenixWeb.ItemController do
  use BenchmarkPhoenixWeb, :controller
  alias BenchmarkPhoenix.Repo

  def create(conn, %{"name" => name, "value" => value}) do
    %{rows: [row], columns: cols} =
      Repo.query!("INSERT INTO items(name,value) VALUES($1,$2) RETURNING id,name,value,created_at::text", [name, value])

    item = Enum.zip(cols, row) |> Map.new()
    conn |> put_status(201) |> json(item)
  end

  def show(conn, %{"id" => id}) do
    case Repo.query!("SELECT id,name,value,created_at::text FROM items WHERE id=$1", [String.to_integer(id)]) do
      %{rows: [row], columns: cols} ->
        item = Enum.zip(cols, row) |> Map.new()
        json(conn, item)
      _ ->
        conn |> put_status(404) |> json(%{error: "not found"})
    end
  end
end
