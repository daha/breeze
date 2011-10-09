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

-module(epc_tests).

-include_lib("eunit/include/eunit.hrl").

tests_with_mock_test_() ->
    {foreach, fun setup/0, fun teardown/1,
      [{with, [T]} ||
       T <- [fun t_start_stop/1,
             fun t_start_workers/1,
             fun t_should_not_allow_start_workers_once/1,
             fun t_restart_worker_when_it_crash/1,
             fun t_restarted_worker_should_keep_its_place/1,
             fun t_multicast/1,
             fun t_sync/1,
             fun t_randomcast/1,
             fun t_keyhashcast/1,
             fun t_keyhashcast_error/1,
             fun t_config_with_one_epc_target/1,
             fun t_should_not_crash_on_random_data_to_gen_server_callbacks/1
            ]]}.

t_start_stop([Pid | _]) ->
    ?assertNot(undefined == process_info(Pid)).

t_start_workers([Pid, WorkerSup | _]) ->
    ?assertEqual(ok, epc:start_workers(Pid, 2)),
    ?assertMatch([_, _], supervisor:which_children(WorkerSup)).

t_should_not_allow_start_workers_once([Pid, WorkerSup | _ ]) ->
    ok = epc:start_workers(Pid, 1),
    ?assertEqual({error, already_started}, epc:start_workers(Pid, 1)),
    ?assertMatch([_], get_workers(WorkerSup)).

t_restart_worker_when_it_crash([Pid, WorkerSup | _]) ->
    ok = epc:start_workers(Pid, 1),
    [Worker] = get_workers(WorkerSup),
    sync_exit(Worker),
    ?assertMatch([_], get_workers(WorkerSup)).

t_restarted_worker_should_keep_its_place([Pid, WorkerSup | _]) ->
    ok = epc:start_workers(Pid, 2),
    Workers = get_workers(WorkerSup),
    Msg1 = {foo, 1},
    Msg2 = {bar, 2},
    ok = epc:keyhashcast(Pid, Msg1),
    ok = epc:sync(Pid),
    [FirstWorker | _ ] = OrderedWorkers = order_workers(Workers, Msg1),
    assert_workers_process_function_is_called(OrderedWorkers, [1, 0], Msg1),
    sync_exit(FirstWorker),
    Workers2 = get_workers(WorkerSup),
    [NewWorker] = Workers2 -- Workers,
    OrderedWorkers2 = replace(OrderedWorkers, FirstWorker, NewWorker),
    keyhashcast_and_assert(Pid, Msg1, OrderedWorkers2, [1, 0]),
    keyhashcast_and_assert(Pid, Msg2, OrderedWorkers2, [0, 1]),
    ok.

t_multicast([Pid, WorkerSup, WorkerMod| _]) ->
    Msg = msg,
    ok = epc:start_workers(Pid, 2),
    epc:multicast(Pid, Msg),
    epc:sync(Pid),
    assert_workers_are_called(WorkerMod, WorkerSup, process, [Msg]),
    ok.

t_sync([Pid, WorkerSup, WorkerMod | _]) ->
    ok = epc:start_workers(Pid, 2),
    ?assertEqual(ok, epc:sync(Pid)),
    assert_workers_are_called(WorkerMod, WorkerSup, sync),
    ok.

t_randomcast([Pid, WorkerSup | _]) ->
    meck:new(random, [passthrough, unstick]),
    ok = epc:start_workers(Pid, 2),
    meck:sequence(random, uniform, 1, [1, 1, 2]),
    Workers = get_workers(WorkerSup),
    ok = epc:randomcast(Pid, Msg = msg),
    ok = epc:sync(Pid),

    OrderedWorkers = order_workers(Workers, Msg),
    assert_workers_random_and_process(OrderedWorkers, [1, 0], Msg),
    randomcast_and_assert(Pid, Msg, OrderedWorkers, [2, 0]),
    randomcast_and_assert(Pid, Msg, OrderedWorkers, [2, 1]),
    meck:unload(random).

t_keyhashcast([Pid, WorkerSup | _]) ->
    ok = epc:start_workers(Pid, 2),
    Workers = get_workers(WorkerSup),
    Msg1 = {foo, 1},
    Msg2 = {bar, 2},
    ok = epc:keyhashcast(Pid, Msg1),
    ok = epc:sync(Pid),
    OrderedWorkers = order_workers(Workers, Msg1),
    assert_workers_process_function_is_called(OrderedWorkers, [1, 0], Msg1),

    keyhashcast_and_assert(Pid, Msg1, OrderedWorkers, [2, 0]),
    keyhashcast_and_assert(Pid, Msg2, OrderedWorkers, [0, 1]),
    ok.

t_keyhashcast_error([Pid | _]) ->
    Msg = foo,
    ?assertEqual({error, {not_a_valid_message, Msg}},
                 epc:keyhashcast(Pid, Msg)).

t_config_with_one_epc_target([Pid1, _WorkerSup1, WorkerMod, MockModule | _]) ->
    {OtherEpc, _WorkerSup2} = start(WorkerMod, MockModule),
    Targets = [{OtherEpc, all}],
    ok = epc:set_targets(Pid1, Targets),
    ok = epc:start_workers(Pid1, 1),
    ?assert(meck:validate(WorkerMod)),
    ?assertEqual(1, meck_improvements:calls(
                   WorkerMod, start_link, [MockModule, [], [{targets, Targets}]])).

t_should_not_crash_on_random_data_to_gen_server_callbacks([Pid |_]) ->
    RandomData = {make_ref(), now(), foo, [self()]},
    Pid ! RandomData,
    gen_server:cast(Pid, RandomData),
    gen_server:call(Pid, RandomData).

should_seed_at_startup_test() ->
    meck:new(random, [passthrough, unstick]),
    S = setup(),
    ?assertEqual(1, meck_improvements:calls_wildcard(
		      random, seed, ['_', '_', '_'])),
    teardown(S),
    meck:unload(random).


% Assert functions
assert_workers_are_called(WorkerMod, WorkerSup, Func) ->
    assert_workers_are_called(WorkerMod, WorkerSup, Func, []).
assert_workers_are_called(WorkerMod, WorkerSup, Func, ExtraArgs) ->
    lists:foreach(fun(Pid) ->
			  ?assert(meck:called(WorkerMod, Func, [Pid] ++ ExtraArgs))
		  end, get_workers(WorkerSup)).

randomcast_and_assert(Pid, Msg, OrderedWorkers, ExpectedList) ->
    ok = epc:randomcast(Pid, Msg),
    ok = epc:sync(Pid),
    assert_workers_random_and_process(OrderedWorkers, ExpectedList, Msg).

keyhashcast_and_assert(Pid, Msg, OrderedWorkers, ExpectedList) ->
    ok = epc:keyhashcast(Pid, Msg),
    ok = epc:sync(Pid),
    assert_workers_process_function_is_called(OrderedWorkers, ExpectedList, Msg).


assert_workers_process_function_is_called(Workers, ExpectedList, Msg) ->
    lists:foreach(
      fun({Worker, Expected}) ->
              ?assertEqual(Expected, meck_improvements:calls(
                             epw, process, [Worker, Msg]))
      end, lists:zip(Workers, ExpectedList)).

assert_workers_random_and_process(Workers, ExpectedList, Msg) ->
    NumberOfWorkers = length(Workers),
    ExpectedRandomUniformCalls = lists:sum(ExpectedList),
    ?assertEqual(ExpectedRandomUniformCalls, meck_improvements:calls(
                   random, uniform, [NumberOfWorkers])),
    assert_workers_process_function_is_called(Workers, ExpectedList, Msg).

% Setup/teardown functions
% TODO: make WorkerMod into a parameter
setup() ->
    WorkerMod = epw,
    meck:new(epw, [passthrough]),
    MockModule = create_behaviour_stub(WorkerMod),
    {Pid, WorkerSup} = start(WorkerMod, MockModule),
    [Pid, WorkerSup, WorkerMod, MockModule].

create_behaviour_stub(epw) ->
    MockModule = epw_mock,
    ok = meck:new(MockModule),
    meck:expect(MockModule, init, fun([]) -> {ok, []} end),
    meck:expect(MockModule, process, fun(_Msg, _EmitFun, State) -> {ok, State} end),
    meck:expect(MockModule, terminate, fun(_, State) -> State end),
    MockModule.

start(WorkerMod, WorkerCallback) ->
    {ok, WorkerSup} = pc_sup:start_link(WorkerMod, WorkerCallback),
    {ok, Pid} = epc:start_link(WorkerMod, WorkerSup),
    {Pid, WorkerSup}.

teardown([Pid, WorkerSup, WorkerMod, MockModule]) ->
    epc:stop(Pid),
    pc_sup:stop(WorkerSup),
    ok = meck:unload(MockModule),
    ok = meck:unload(WorkerMod).

% Getters
get_workers(WorkerSup) ->
    Children = supervisor:which_children(WorkerSup),
    lists:map(fun(Child) -> element(2, Child) end, Children).


% Other help methods

% Put the worker that receive the first process call first in the list
order_workers(Workers, Msg) ->
    case meck_improvements:calls(epw, process, [hd(Workers), Msg]) of
        1 ->
            Workers;
        _ -> % Reverse the order
            lists:reverse(Workers)
    end.

replace([Old | Rest], Old, New) ->
    [New | Rest];
replace([Other | Rest], Old, New) ->
    [Other | replace(Rest, Old, New)];
replace([], _Old, _New) ->
    [].

sync_exit(Pid) ->
    Ref = monitor(process, Pid),
    exit(Pid, crash),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    timer:sleep(50). %% TODO: Find a way to get rid of this sleep.

