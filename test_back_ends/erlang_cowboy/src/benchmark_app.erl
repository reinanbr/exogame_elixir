-module(benchmark_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Connect to PostgreSQL with retry
    DbHost = os:getenv("DB_HOST", "postgres"),
    ok = connect_db(DbHost, 30),

    %% Start WebSocket hub
    ws_hub:start_link(),

    %% Cowboy routes
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/items", item_handler, []},
            {"/items/:id", item_handler, []},
            {"/ws", ws_handler, []}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(http, [{port, 8080}],
                                 #{env => #{dispatch => Dispatch}}),
    io:format("Erlang/Cowboy server on :8080~n"),
    benchmark_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(http),
    ok.

connect_db(_Host, 0) ->
    error(db_connection_failed);
connect_db(Host, Retries) ->
    case epgsql:connect(Host, "bench", "bench",
                        [{database, "bench"}, {port, 5432}]) of
        {ok, Conn} ->
            %% Store in persistent_term for global access
            persistent_term:put(pg_conn, Conn),
            ok;
        {error, _Reason} ->
            io:format("DB not ready, retrying (~p/30)...~n", [31 - Retries]),
            timer:sleep(1000),
            connect_db(Host, Retries - 1)
    end.
