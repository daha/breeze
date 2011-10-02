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
-module(epc_tests).

-include_lib("eunit/include/eunit.hrl").

tests_with_mock_test_() ->
    {foreach, fun setup/0, fun teardown/1,
      [{with, [T]} || T <- [fun t_start_stop/1,
                            fun t_start_workers/1,
                            fun t_multicast/1,
                            fun t_sync/1]]}.

t_start_stop([Pid | _]) ->
    ?assertNot(undefined == process_info(Pid)).

t_start_workers([Pid, SupervisorPid | _]) ->
    WorkerSupPid = get_worker_sup_pid(SupervisorPid),
    ?assertEqual(ok, epc:start_workers(Pid, 2)),
    ?assertMatch([_,_], supervisor:which_children(WorkerSupPid)),
    ?assertEqual(ok, epc:start_workers(Pid, 1)),
    ?assertMatch([_,_,_], supervisor:which_children(WorkerSupPid)).

t_multicast([Pid, SupervisorPid | _]) ->
    Msg = msg,
    ok = epc:start_workers(Pid, 2),
    epc:multicast(Pid, Msg), % async
    epc:sync(Pid), % to make sure epc has processed the message
    assert_workers_are_called(SupervisorPid, process, [Msg]),
    ok. % So the test shows in the stack if the assert above fail

t_sync([Pid, SupervisorPid | _]) ->
    ok = epc:start_workers(Pid, 2),
    ?assertEqual(ok, epc:sync(Pid)),
    assert_workers_are_called(SupervisorPid, sync),
    ok. % So the test shows in the stack if the assert above fail

so_not_start_with_invalid_callback_module_test() ->
    CallbackModule = invalid_callback_module,
    ?assertEqual({error, {invalid_callback_module, CallbackModule}},
        epc_sup:start_link(epc_name, invalid_callback_module)).

% Internal functions
setup() ->
    MockModule = epw_mock,
    meck:new(epw, [passthrough]),
    ok = meck:new(MockModule),
    meck:expect(MockModule, init, fun([]) -> {ok, []} end),
    meck:expect(MockModule, process, fun(_Msg, State) -> {ok, State} end),
    meck:expect(MockModule, terminate, fun(_, State) -> State end),
    {Pid, SupervisorPid} = start(MockModule),
    [Pid, SupervisorPid, MockModule].

teardown([_Pid, SupervisorPid, MockModule]) ->
    epc_sup:stop(SupervisorPid),
    ok = meck:unload(MockModule),
    ok = meck:unload(epw).

get_epc_pid(SupPid) ->
    get_supervised_pid(SupPid, epc_sup:get_controller_id()).

get_worker_sup_pid(SupPid) ->
    get_supervised_pid(SupPid, epc_sup:get_worker_sup_id()).

get_supervised_pid(SupPid, SupId) ->
    Children = supervisor:which_children(SupPid),
    {SupId, Pid, _, _} = proplists:lookup(SupId, Children),
    Pid.

get_workers(SupPid) ->
    WorkerSupPid = get_worker_sup_pid(SupPid),
    Children = supervisor:which_children(WorkerSupPid),
    lists:map(fun(Child) -> element(2, Child) end, Children).

start(CallbackModule) ->
    {ok, SupervisorPid} = epc_sup:start_link(epc_name, CallbackModule),
    Pid = get_epc_pid(SupervisorPid),
    {Pid, SupervisorPid}.

assert_workers_are_called(SupervisorPid, Func) ->
    assert_workers_are_called(SupervisorPid, Func, []).
assert_workers_are_called(SupervisorPid, Func, ExtraArgs) ->
    lists:foreach(fun(Pid) ->
			  ?assert(meck:called(epw, Func, [Pid] ++ ExtraArgs))
		  end, get_workers(SupervisorPid)).

