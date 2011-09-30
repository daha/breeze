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
-module(epc_sup).

-behaviour(supervisor).
%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([start_link/2]).
-export([stop/1]).
-export([get_worker_sup_pid/1]).

-ifdef(TEST).
-export([get_controller_id/0]).
-export([get_worker_sup_id/0]).
-endif.

%% --------------------------------------------------------------------
%% Internal exports
%% --------------------------------------------------------------------
-export([init/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------

%% ====================================================================
%% External functions
%% ====================================================================
start_link(ControllerName, WorkerCallback) ->
    case epw:validate_module(WorkerCallback) of
        true ->
            supervisor:start_link(?MODULE, [ControllerName, WorkerCallback]);
        false ->
            {error, {invalid_callback_module, WorkerCallback}}
    end.

stop(Pid) ->
    true = exit(Pid, normal),
    ok.

get_worker_sup_pid(Pid) ->
    Children = supervisor:which_children(Pid),
    {worker_sup, WorkerSupPid, _, _} = proplists:lookup(worker_sup, Children),
    {ok, WorkerSupPid}.

get_controller_id() ->
    controller.

get_worker_sup_id() ->
    worker_sup.

%% ====================================================================
%% Server functions
%% ====================================================================
%% --------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok,  {SupFlags,  [ChildSpec]}} |
%%          ignore                          |
%%          {error, Reason}
%% --------------------------------------------------------------------
init([ControllerName, WorkerCallback]) ->
    WorkerSup =   {get_worker_sup_id(), {epw_sup, start_link,[WorkerCallback]},
                   permanent, infinity, supervisor, [epw_sup]},
    Controller = {get_controller_id(),
                  {epc, start_link, [ControllerName, self()]},
                  permanent, 2000, worker, [epc]},
    ChildSpecs = [WorkerSup, Controller],
    {ok,{{one_for_all,0,1}, ChildSpecs}}.

%% ====================================================================
%% Internal functions
%% ====================================================================
