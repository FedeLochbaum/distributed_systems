-module(manager).
-export([start/1, newManager/2]).

start(Name) ->
  register(Name, spawn(fun() -> initManager(Name) end)).

newManager(Name, Managers) ->
  register(Name, spawn(fun() -> initNewManager(Name, Managers) end)).

initNewManager(Name, Managers) ->
  Manager = lists:nth(rand:uniform(length(Managers)), Managers), % selecciono un manager random
  Manager ! {newManager, Name},
  receive
    {yourNewServer, Pid, {NameServer, Peers, Next, I3Rtree, {InitialX, InitialY}, {FinalX, FinalY}, {MaxRangeX, MaxRangeY}, {LoadBalancing,LoadBalancing}}, Peers, ToMonitor} ->  % aca deberiamos pasarle todo lo que tiene la funcion server (obviamente con su estado)
      createNewServer(NameServer, Peers, Next, I3Rtree, {InitialX, InitialY}, {FinalX, FinalY}, {MaxRangeX, MaxRangeY}, {LoadBalancing,LoadBalancing}), % asumo que aca podre ver el nombre del server.
      Monitor = monitor(process, ToMonitor),
      lists:map(fun(Peer) -> Peer ! ok end, Peers),
      manager(Name, [NameServer], Managers, {ToMonitor,Monitor})
  end.


createNewServer(NameServer, Peers, Next, I3Rtree, {InitialX, InitialY}, {FinalX, FinalY}, {MaxRangeX, MaxRangeY}, {LoadBalancing,LoadBalancing}) ->
io:format("Selected Server is ~w~n", [{NameServer, Peers, Next, {InitialX, InitialY}, {FinalX, FinalY}, {MaxRangeX, MaxRangeY}, {LoadBalancing,LoadBalancing}}]),
register(NameServer,
            spawn(fun() ->
              distributedServer:server(NameServer, Peers, Next, I3Rtree, {InitialX, InitialY}, {FinalX, FinalY}, {MaxRangeX, MaxRangeY}, {LoadBalancing,LoadBalancing})
            end)).  % falta levantar este server en esta pc. (con todo este estado)



initManager(Name) ->
  receive
    {servers, Servers} ->
      waitForPeers(Name, Servers)
  end.

waitForPeers(Name, Servers) ->
  receive
    {managers, Managers, ToMonitor} ->
      Monitor = monitor(process, ToMonitor),
      manager(Name, Servers, Managers, {ToMonitor,Monitor})
  end.

getWeight(Peers) ->
  lists:map(fun(Peer) -> Peer ! {weight, self()} end, Peers),
  receiveReplies(length(Peers), []).

receiveReplies(0, Replies) ->
  Replies;

receiveReplies(Peers, Replies) ->
  receive
    {weightResult, Pid, Server, Weight} ->
      Res = Replies ++ [{Pid, Server, Weight}];
    _ ->
      Res = Replies
  end,
  receiveReplies(Peers -1, Res).

maxWeight(Replies) ->
F = fun({Manager, Server, Weight}, {ManagerMax, ServerMax, WeightMax}) ->
    if
      Weight >= WeightMax ->
        Res = {Manager, Server, Weight};
      true ->
        Res = {ManagerMax, ServerMax, WeightMax}
    end,
    Res
  end,
 lists:foldl(F, {0,0,0}, Replies).


manager(Name, Servers, Managers, {ToMonitor,Monitor}) ->
  receive
    {newManager, NewManager} ->
      spawn(
            fun() ->
              Replies = getWeight(Managers ++ [Name]),
              {Manager, Server, Weight} = maxWeight(Replies),
              Manager ! {getServer, Server, NewManager}
      end),
      manager(Name, Servers, Managers, {ToMonitor,Monitor});

    {weight, Pid} ->
      Replies = distributedServer:getWeight(Servers),
      lists:map(fun(S) -> S ! ok end, Servers),
      {S,_, Weight} = distributedServer:maxWeight(Replies),
      Pid ! {weightResult, Name, S, Weight},
      manager(Name, Servers, Managers, {ToMonitor,Monitor});

    {getServer, Server, NewManager} ->
      case length(Servers) > 1 of
        true ->
          Server ! {state, Name};
        false ->
          Server ! partition,
          Server ! {state, Name}
      end,

      receive
        {state, State} ->
          Server ! {stopServerForClone, Name},
           receive
             {ok, Peers} ->
               timer:sleep(2000),
               Server ! stop,
               demonitor(Monitor),
               NewManager ! {yourNewServer, Name, State, Peers, ToMonitor},
               manager(Name, lists:subtract(Servers, [Server]), Managers, {NewManager,monitor(process, NewManager)})
          %     Server ! stop,
          %     manager(Name, lists:subtract(Servers, [Server]), Managers)
          end
      end;
    {'DOWN', Monitor, process, Object, Info} ->
          io:format("~w died; ~w~n", [Object, Info]),
          manager(Name, Servers, Managers, {ToMonitor,Monitor})

  end.
