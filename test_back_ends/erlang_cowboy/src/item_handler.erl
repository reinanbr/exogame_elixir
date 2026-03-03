-module(item_handler).
-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path(Req0),
    handle(Method, Path, Req0, State).

handle(<<"POST">>, <<"/items">>, Req0, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Json = jiffy:decode(Body, [return_maps]),
    Name = maps:get(<<"name">>, Json, undefined),
    Value = maps:get(<<"value">>, Json, <<"">>),
    case Name of
        undefined ->
            Resp = cowboy_req:reply(400,
                #{<<"content-type">> => <<"application/json">>},
                <<"{\"error\":\"missing name\"}">>, Req1),
            {ok, Resp, State};
        _ ->
            Conn = persistent_term:get(pg_conn),
            {ok, _Cols, Rows} = epgsql:equery(Conn,
                "INSERT INTO items (name, value) VALUES ($1, $2) RETURNING id, name, value",
                [Name, Value]),
            [{Id, RName, RValue}] = Rows,
            RespJson = jiffy:encode(#{
                <<"id">> => Id,
                <<"name">> => RName,
                <<"value">> => RValue
            }),
            Resp = cowboy_req:reply(201,
                #{<<"content-type">> => <<"application/json">>},
                RespJson, Req1),
            {ok, Resp, State}
    end;

handle(<<"GET">>, _Path, Req0, State) ->
    IdBin = cowboy_req:binding(id, Req0),
    Id = binary_to_integer(IdBin),
    Conn = persistent_term:get(pg_conn),
    case epgsql:equery(Conn,
            "SELECT id, name, value FROM items WHERE id=$1", [Id]) of
        {ok, _Cols, [{RId, RName, RValue}]} ->
            RespJson = jiffy:encode(#{
                <<"id">> => RId,
                <<"name">> => RName,
                <<"value">> => RValue
            }),
            Resp = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                RespJson, Req0),
            {ok, Resp, State};
        {ok, _Cols, []} ->
            Resp = cowboy_req:reply(404,
                #{<<"content-type">> => <<"application/json">>},
                <<"{\"error\":\"not found\"}">>, Req0),
            {ok, Resp, State}
    end;

handle(_, _, Req0, State) ->
    Resp = cowboy_req:reply(405, #{}, <<>>, Req0),
    {ok, Resp, State}.
