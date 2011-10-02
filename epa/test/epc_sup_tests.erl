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
-module(epc_sup_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CONTROLLER, test_controller).

start_stop_test() ->
    {ok, Pid} = epc_sup:start_link(?CONTROLLER, epw_dummy),
    ?assert(is_process_alive(Pid)),
    ok = epc_sup:stop(Pid).

start_epc_test() ->
    Pid = start(),
    Expected = [{specs,2},
                {active,2},
                {supervisors,1},
                {workers,1}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    ?assertMatch(Pid0 when is_pid(Pid0), whereis(?CONTROLLER)),
    stop(Pid).

get_worker_sup_pid_test() ->
    Pid = start(),
    {ok, WorkerSupPid} = epc_sup:get_worker_sup_pid(Pid),
    % Ugly way of verifying this is a supervisor
    ?assertEqual([], supervisor:which_children(WorkerSupPid)),
    stop(Pid).

% internal
start() ->
    {ok, Pid} = epc_sup:start_link(?CONTROLLER, epw_dummy),
    Pid.

stop(Pid) ->
   epc_sup:stop(Pid).
