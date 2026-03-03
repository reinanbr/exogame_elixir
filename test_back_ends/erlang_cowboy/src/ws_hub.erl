-module(ws_hub).
-behaviour(gen_server).
-export([start_link/0, add/1, remove/1, broadcast/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

add(Pid) ->
    gen_server:cast(?MODULE, {add, Pid}).

remove(Pid) ->
    gen_server:cast(?MODULE, {remove, Pid}).

broadcast(Msg) ->
    gen_server:cast(?MODULE, {broadcast, Msg}).

%% gen_server callbacks
init([]) ->
    {ok, #{clients => #{}}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({add, Pid}, #{clients := Clients} = State) ->
    erlang:monitor(process, Pid),
    {noreply, State#{clients := Clients#{Pid => true}}};

handle_cast({remove, Pid}, #{clients := Clients} = State) ->
    {noreply, State#{clients := maps:remove(Pid, Clients)}};

handle_cast({broadcast, Msg}, #{clients := Clients} = State) ->
    maps:foreach(fun(Pid, _) ->
        Pid ! {ws_broadcast, Msg}
    end, Clients),
    {noreply, State}.

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #{clients := Clients} = State) ->
    {noreply, State#{clients := maps:remove(Pid, Clients)}};

handle_info(_Info, State) ->
    {noreply, State}.
