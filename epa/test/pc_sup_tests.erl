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
%%
%% @end

-module(pc_sup_tests).

-include_lib("eunit/include/eunit.hrl").

% use epw as a worker
epw_start_stop_test() ->
    test_start_stop(epw, epw_dummy), ok.

epw_start_workers_test() ->
    test_start_workers(epw, epw_dummy), ok.

epw_fail_to_start_worker_test() ->
    test_fail_to_start_worker(epw, epw_dummy), ok.

epw_workers_should_be_temporary_test() ->
    test_workers_should_be_temporary(epw, epw_dummy), ok.

epw_should_pass_configuration_to_worker_test() ->
    test_should_pass_configuration_to_worker(epw, epw_dummy), ok.

% use eg as a worker
eg_start_stop_test() ->
    test_start_stop(eg, eg_dummy), ok.

eg_start_workers_test() ->
    test_start_workers(eg, eg_dummy), ok.

eg_fail_to_start_worker_test() ->
    test_fail_to_start_worker(eg, eg_dummy), ok.

eg_workers_should_be_temporary_test() ->
    test_workers_should_be_temporary(eg, eg_dummy), ok.

eg_should_pass_configuration_to_worker_test() ->
    test_should_pass_configuration_to_worker(eg, eg_dummy), ok.

%% Common tests
test_start_stop(WorkerMod, CallbackModule) ->
    {ok, Pid} = pc_sup:start_link(WorkerMod, CallbackModule),
    ?assert(is_process_alive(Pid)),
    Expected = [{specs, 1},
                {active, 0},
                {supervisors, 0},
                {workers, 0}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    ok = pc_sup:stop(Pid),
    ok = pc_sup:stop(Pid).

test_start_workers(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    ?assertMatch({ok, [_Pid1, _Pid2]},
                 pc_sup:start_workers(Pid, 2)),
    Expected = [{specs, 1},
                {active, 2},
                {supervisors, 0},
                {workers, 2}],
    ?assert(meck:called(WorkerMod, start_link, [CallbackModule, [], []])),
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    stop(Pid, WorkerMod).

test_should_pass_configuration_to_worker(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    WorkerOpts = [make_ref()],
    Opts = [make_ref()],
    {ok, [_ChildPid]} =
        pc_sup:start_workers(Pid, 1, WorkerOpts, Opts),
    ?assert(meck:called(WorkerMod, start_link,
                        [CallbackModule, WorkerOpts, Opts])),
    stop(Pid, WorkerMod).

test_fail_to_start_worker(WorkerMod, _CallbackModule) ->
    Pid = start(WorkerMod, invalid_module),
    ?assertMatch({error, _Reason}, pc_sup:start_workers(Pid, 1)),
    stop(Pid, WorkerMod).

test_workers_should_be_temporary(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    {ok, [ChildPid1, _ChildPid2]} = pc_sup:start_workers(Pid, 2),
    Ref = monitor(process, ChildPid1),
    exit(ChildPid1, abnormal),
    receive {'DOWN', Ref, process, ChildPid1, _Info} -> ok end,
    Expected = [{specs, 1},
                {active, 1},
                {supervisors, 0},
                {workers, 1}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    stop(Pid, WorkerMod).

%% Internal functions
start(WorkerMod, CallbackModule) ->
    {ok, Pid} = pc_sup:start_link(WorkerMod, CallbackModule),
    meck:new(WorkerMod, [passthrough]),
    Pid.

stop(Pid, WorkerMod) ->
   pc_sup:stop(Pid),
   meck:unload(WorkerMod).
