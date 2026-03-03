-module(ws_handler).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

init(Req, State) ->
    {cowboy_websocket, Req, State, #{idle_timeout => infinity}}.

websocket_init(State) ->
    ws_hub:add(self()),
    {ok, State}.

websocket_handle({text, Msg}, State) ->
    ws_hub:broadcast(Msg),
    {ok, State};
websocket_handle(_Data, State) ->
    {ok, State}.

websocket_info({ws_broadcast, Msg}, State) ->
    {[{text, Msg}], State};
websocket_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _Req, _State) ->
    ws_hub:remove(self()),
    ok.
