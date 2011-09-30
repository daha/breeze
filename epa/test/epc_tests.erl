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

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    {Pid, SupervisorPid} = start(),
    ?assertNot(undefined == process_info(Pid)),
    epc_sup:stop(SupervisorPid).

start_workers_test() ->
    {Pid, SupervisorPid} = start(),
    WorkerSupPid = get_worker_sup_pid(SupervisorPid),
    ?assertEqual(ok, epc:start_workers(Pid, 2)),
    ?assertMatch([_,_], supervisor:which_children(WorkerSupPid)),
    ?assertEqual(ok, epc:start_workers(Pid, 1)),
    ?assertMatch([_,_,_], supervisor:which_children(WorkerSupPid)),
    epc_sup:stop(SupervisorPid).

so_not_start_with_invalid_callback_module_test() ->
    CallbackModule = invalid_callback_module,
    ?assertEqual({error, {invalid_callback_module, CallbackModule}},
        epc_sup:start_link(epc_name, invalid_callback_module)).

tests_with_mock_test_() ->
    {foreach, fun setup/0, fun teardown/1,
      [{with, [T]} || T <- [fun multicast_/1]]}.

multicast_({Pid, _SupervisorPid, MockModule}) ->
    Msg = msg,
    ok = epc:start_workers(Pid, 2),
    epc:multicast(Pid, Msg),
    ?assert(meck:validate(MockModule)),
    %% TODO: improve the testing, this is asynchronous
    wait_until(2, fun() ->
                          meck_improvements:count_calls(MockModule, process, [Msg, []])
               end).

% Internal functions
setup() ->
    MockModule = epw_mock,
    ok = meck:new(MockModule),
    meck:expect(MockModule, init, fun([]) -> {ok, []} end),
    meck:expect(MockModule, process, fun(_Msg, State) -> {ok, State} end),
    meck:expect(MockModule, terminate, fun(_, State) -> State end),
    {Pid, SupervisorPid} = start(MockModule),
    {Pid, SupervisorPid, MockModule}.

teardown({_Pid, SupervisorPid, MockModule}) ->
    epc_sup:stop(SupervisorPid),
    catch meck:unload(MockModule).


get_epc_pid(SupPid) ->
    get_supervised_pid(SupPid, epc_sup:get_controller_id()).

get_worker_sup_pid(SupPid) ->
    get_supervised_pid(SupPid, epc_sup:get_worker_sup_id()).

get_supervised_pid(SupPid, SupId) ->
    Children = supervisor:which_children(SupPid),
    {SupId, Pid, _, _} = proplists:lookup(SupId, Children),
    Pid.

start() ->
    start(epw_dummy).
start(CallbackModule) ->
    {ok, SupervisorPid} = epc_sup:start_link(epc_name, CallbackModule),
    Pid = get_epc_pid(SupervisorPid),
    {Pid, SupervisorPid}.

wait_until(Expected, EvalFun) ->
    case EvalFun() of
        Expected ->
            ok;
        _ ->
            wait_until(Expected, EvalFun)
    end.

-endif.
