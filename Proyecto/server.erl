-module(server).
-export([start/1,stop/1,timeNow/0]).
-import(rstar, [rstar/1]).

start(Name) ->
  register(Name, spawn(fun() -> server(i3RTree:new()) end)).

stop(Server) ->
Server ! stop.

server(I3Rtree) ->
  receive
    {subscribe, Pid, {X, Y}} ->
      NRtree = i3RTree:subscribe(Pid, {X, Y}, timeNow(), I3Rtree),
      Pid ! ok,
      server(NRtree);
    {unsubscribe, Pid} ->
      NRtree = i3RTree:unsubscribe(Pid, I3Rtree),
      Pid ! ok,
      server(NRtree);
    {move, Pid, {X, Y}} ->
      NRtree = i3RTree:move(Pid, {X,Y}, timeNow(), I3Rtree),
      server(NRtree);
    {timelapse, Region, Instant, Process} ->
      spawn(fun() -> timelapse_query(Region, Instant, Process, I3Rtree) end),
      server(I3Rtree);
    {interval, Region, {Ti,Tk}, Process} ->
      spawn(fun() -> interval_query(Region, {Ti,Tk}, Process, I3Rtree) end),
      server(I3Rtree);
    {event, RegionMin, RegionMax, Process} ->
      spawn(fun() -> event_query(RegionMin, RegionMax, Process, I3Rtree) end),
      server(I3Rtree);
    {track, Pid, {Ti,Tk}, Process} ->
      spawn(fun() -> track_query(Pid, {Ti,Tk}, Process, I3Rtree) end),
      server(I3Rtree);
    {position, Pid, Process} ->
      spawn(fun() -> position_query(Pid, Process, I3Rtree) end),
      server(I3Rtree);
    stop ->
      ok
  end.


timelapse_query(Region, Instant, Process, I3Rtree) ->
  Reply = i3RTree:timelapse_query(Region, Instant, I3Rtree),
  io:format("Query timeLapse: ~w ~w~n", [Instant, Reply]),
  Process ! {reply, Reply}.

interval_query(Region, {Ti,Tk}, Process, I3Rtree) ->
  Reply = i3RTree:interval_query(Region, {Ti,Tk}, I3Rtree),
  io:format("Query interval: ~w ~w ~w~n", [Region, {Ti,Tk} ,Reply]),
  Process ! {reply, Reply}.

event_query(RegionMin, RegionMax, Process, I3Rtree) ->
  Reply = i3RTree:event_query(RegionMin, RegionMax, I3Rtree),
  io:format("Query event: ~w ~w ~w~n", [RegionMin, RegionMax ,Reply]),
  Process ! {reply, Reply}.

track_query(Pid, {Ti,Tk}, Process, I3Rtree) ->
  Reply = i3RTree:track_query(Pid, {Ti,Tk}, I3Rtree),
  io:format("Query track: ~w ~w ~w~n", [Pid, {Ti,Tk}, Reply]),
  Process ! {reply, Reply}.

position_query(Pid, Process, I3Rtree) ->
  Reply = i3RTree:position_query(Pid, I3Rtree),
  io:format("Query position: ~w ~w~n", [Pid, Reply]),
  Process ! {reply, Reply}.


timeNow() ->
  {H, M, S} = erlang:time(),
  H * 3600 + M * 60 + S.
