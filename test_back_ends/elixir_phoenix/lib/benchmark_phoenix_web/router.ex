defmodule BenchmarkPhoenixWeb.Router do
  use BenchmarkPhoenixWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BenchmarkPhoenixWeb do
    pipe_through :api
    post "/items", ItemController, :create
    get "/items/:id", ItemController, :show
  end
end
