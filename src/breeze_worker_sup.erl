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

%% @author David Haglund
%% @copyright 2011, David Haglund
%% @doc
%% Supervisor for breeze_processing_worker and breeze_generating_worker
%% @end

-module(breeze_worker_sup).

-behaviour(supervisor).

%% API
-export([start_link/2]).
-export([stop/1]).
-export([start_workers/2]).
-export([start_workers/4]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link(WorkerBehaviour, Module) ->
%%           {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(WorkerBehaviour, Module) ->
    supervisor:start_link(?MODULE, [WorkerBehaviour, Module]).

stop(Pid) ->
    Ref = monitor(process, Pid),
    true = exit(Pid, normal),
    receive {'DOWN', Ref, process, Pid, _} -> ok end,
    ok.

start_workers(Pid, NumberOfChildren) ->
    start_workers(Pid, NumberOfChildren, _WorkerOpts = [], _Opts = []).

start_workers(Pid, NumberOfChildren, WorkerOpts, Opts) ->
    i_start_workers(Pid, NumberOfChildren, WorkerOpts, Opts, _Pids = []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([WorkerBehaviour, CallbackModule]) ->
    ChildSpec = {worker, {WorkerBehaviour, start_link, [CallbackModule]},
                 temporary, 5000, worker, [WorkerBehaviour, CallbackModule]},
    {ok, {{simple_one_for_one, 100, 1}, [ChildSpec]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
i_start_workers(_SupervisorPid, _NumberOfChildren = 0, _WOpts, _Opts, Pids) ->
    {ok, Pids};
i_start_workers(SupervisorPid, NumberOfChildren, WorkerOpts, Opts, Pids) ->
    case i_start_child(SupervisorPid, WorkerOpts, Opts) of
        {ok, Pid} ->
            i_start_workers(SupervisorPid, NumberOfChildren-1, WorkerOpts, Opts,
                            [Pid | Pids]);
        {error, _} = Error ->
            Error
    end.

i_start_child(SupervisorPid, WorkerOpts, Opts) ->
    supervisor:start_child(SupervisorPid, [WorkerOpts, Opts]).
