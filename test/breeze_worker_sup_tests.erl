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

-module(breeze_worker_sup_tests).

-include_lib("eunit/include/eunit.hrl").

% use breeze_processing_worker as a worker
processing_worker_start_stop_test() ->
    test_start_stop(breeze_processing_worker, pw_dummy), ok.

processing_worker_start_workers_test() ->
    test_start_workers(breeze_processing_worker, pw_dummy), ok.

processing_worker_fail_to_start_worker_test() ->
    test_fail_to_start_worker(breeze_processing_worker, pw_dummy), ok.

processing_worker_workers_should_be_temporary_test() ->
    test_workers_should_be_temporary(breeze_processing_worker, pw_dummy), ok.

processing_worker_should_pass_configuration_to_worker_test() ->
    test_should_pass_configuration_to_worker(breeze_processing_worker,
					     pw_dummy),
    ok.

% use breeze_generating_worker as a worker
generating_worker_start_stop_test() ->
    test_start_stop(breeze_generating_worker, gw_dummy), ok.

generating_worker_start_workers_test() ->
    test_start_workers(breeze_generating_worker, gw_dummy), ok.

generating_worker_fail_to_start_worker_test() ->
    test_fail_to_start_worker(breeze_generating_worker, gw_dummy), ok.

generating_worker_workers_should_be_temporary_test() ->
    test_workers_should_be_temporary(breeze_generating_worker, gw_dummy), ok.

generating_worker_should_pass_configuration_to_worker_test() ->
    test_should_pass_configuration_to_worker(breeze_generating_worker,
					     gw_dummy),
    ok.

%% Common tests
test_start_stop(WorkerMod, CallbackModule) ->
    {ok, Pid} = breeze_worker_sup:start_link(WorkerMod, CallbackModule),
    ?assert(is_process_alive(Pid)),
    sup_tests_common:expect_one_spec_none_active(Pid),
    ok = breeze_worker_sup:stop(Pid),
    ok = breeze_worker_sup:stop(Pid).

test_start_workers(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    ?assertMatch({ok, [_Pid1, _Pid2]},
                 breeze_worker_sup:start_workers(Pid, 2)),
    ?assert(meck:called(WorkerMod, start_link, [CallbackModule, [], []])),
    sup_tests_common:expect_supervisor_children(Pid, _Sups = 0, _Workers = 2),
    stop(Pid, WorkerMod).

test_should_pass_configuration_to_worker(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    WorkerOpts = [make_ref()],
    Opts = [make_ref()],
    {ok, [_ChildPid]} =
        breeze_worker_sup:start_workers(Pid, 1, WorkerOpts, Opts),
    ?assert(meck:called(WorkerMod, start_link,
                        [CallbackModule, WorkerOpts, Opts])),
    stop(Pid, WorkerMod).

test_fail_to_start_worker(WorkerMod, _CallbackModule) ->
    Pid = start(WorkerMod, invalid_module),
    ?assertMatch({error, _Reason}, breeze_worker_sup:start_workers(Pid, 1)),
    stop(Pid, WorkerMod).

test_workers_should_be_temporary(WorkerMod, CallbackModule) ->
    Pid = start(WorkerMod, CallbackModule),
    {ok, [ChildPid1, _ChildPid2]} = breeze_worker_sup:start_workers(Pid, 2),
    Ref = monitor(process, ChildPid1),
    exit(ChildPid1, abnormal),
    receive {'DOWN', Ref, process, ChildPid1, _Info} -> ok end,
    sup_tests_common:expect_one_active_worker(Pid),
    stop(Pid, WorkerMod).

%% Internal functions
start(WorkerMod, CallbackModule) ->
    {ok, Pid} = breeze_worker_sup:start_link(WorkerMod, CallbackModule),
    meck:new(WorkerMod, [passthrough]),
    Pid.

stop(Pid, WorkerMod) ->
   breeze_worker_sup:stop(Pid),
   meck:unload(WorkerMod).
