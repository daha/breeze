%%====================================================================
%% Copyright (c) 2011, David Haglund
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%%     * Redistributions of source code must retain the above
%%       copyright notice, this list of conditions and the following
%%       disclaimer.
%%
%%     * Redistributions in binary form must reproduce the above
%%       copyright notice, this list of conditions and the following
%%       disclaimer in the documentation and/or other materials
%%       provided with the distribution.
%%
%%     * Neither the name of the copyright holder nor the names of its
%%       contributors may be used to endorse or promote products
%%       derived from this software without specific prior written
%%       permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
%% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
%% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
%% STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
%% OF THE POSSIBILITY OF SUCH DAMAGE.
%%====================================================================
-module(epw_sup).

-behaviour(supervisor).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([start_link/0]).
-export([stop/1]).
-export([start_worker/2]).
-export([start_workers/3]).

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([init/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------
-define(SERVER, ?MODULE).

%% --------------------------------------------------------------------
%% Records
%% --------------------------------------------------------------------

%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
    supervisor:start_link(?MODULE, []).

stop(Pid) ->
    true = exit(Pid, normal),
    ok.

start_worker(Pid, Module) ->
   case start_workers(Pid, Module, 1) of 
       {ok, [WorkerPid]} ->
           {ok, WorkerPid};
       Error ->
           Error
   end.

start_workers(Pid, Module, NumberOfChildren) ->
    start_workers(Pid, Module, NumberOfChildren, []).


%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init([]) ->
    {ok,{{simple_one_for_one,0,1}, []}}.

%% ====================================================================
%% Internal functions
%% ====================================================================
start_workers(_SupervisorPid, _Module, _NumberOfChildren = 0, Pids) ->
    {ok, Pids};
start_workers(SupervisorPid, Module, NumberOfChildren, Pids) ->
    case check_start_child(SupervisorPid, make_child_spec(Module)) of 
        {ok, Pid} ->
            start_workers(SupervisorPid, Module, NumberOfChildren -1, 
                          [Pid | Pids]);
        {error, _} = Error ->
            stop_children(SupervisorPid, Pids),
            Error
    end.

stop_children(SupervisorPid, Pids) ->
    lists:foreach(
      fun(Pid) -> supervisor:terminate_child(SupervisorPid, Pid) end, Pids).

    


check_start_child(SupervisorPid, ChildSpec) ->
    case supervisor:check_childspecs([ChildSpec]) of
        ok ->
          start_child(SupervisorPid, ChildSpec);
        Error ->
            Error
    end.

start_child(SupervisorPid, ChildSpec) ->
    case supervisor:start_child(SupervisorPid, ChildSpec) of
        {ok, WorkerPid} -> 
            {ok, WorkerPid};
        {ok, WorkerPid, _} ->
            {ok, WorkerPid};
        {error, _} = Error ->
            Error
    end.

make_child_spec(Module) ->
    {make_ref(), {epw, start_link, [Module, []]},
     transient, 5000, worker, [epw, Module]}.

