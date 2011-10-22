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

-module(breeze_worker_controller_tests).

-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

-define(EPC_NAME, worker_controller_name).

-define(assert_workers(WorkerSup, ExpectedWorkers),
	?assertEqual(ExpectedWorkers, length(get_workers(WorkerSup)))).

-define(assert_invalid_message(Pid, Func, Msg),
	?assertEqual({error, {not_a_valid_message, Msg}},
		     breeze_worker_controller:Func(Pid, Msg))).

tests_with_mock_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} ||
      T <- [fun ?MODULE:t_start_stop/1,
            fun ?MODULE:t_register_name/1,
            fun ?MODULE:t_start_workers/1,
            fun ?MODULE:t_start_workers_with_same_config/1,
            fun ?MODULE:t_should_not_allow_start_workers_once/1,
            fun ?MODULE:t_restart_worker_when_it_crash/1,
            fun ?MODULE:t_restarted_worker_should_keep_its_place/1,
            fun ?MODULE:t_pass_worker_config_to_worker_on_restart/1,
            fun ?MODULE:t_multicast/1,
            fun ?MODULE:t_sync/1,
            fun ?MODULE:t_random_cast/1,
            fun ?MODULE:t_keyhash_cast/1,
            fun ?MODULE:t_keyhash_cast_error/1,
            fun ?MODULE:t_enable_dynamic_workers/1,
            fun ?MODULE:t_cant_activate_dynamic_workers_with_workers_started/1,
            fun ?MODULE:t_cant_start_workers_after_enabled_dynamic_workers/1,
            fun ?MODULE:t_start_dynamic_worker_when_doing_first_keycast/1,
            fun ?MODULE:t_start_dynamic_worker_should_set_targets/1,
            fun ?MODULE:t_should_send_message_to_started_worker/1,
            fun ?MODULE:t_should_not_start_new_worker_with_same_key/1,
            fun ?MODULE:t_should_remember_the_old_dynamic_workers/1,
            fun ?MODULE:t_dynamic_workers_should_be_restarted_if_they_crash/1,
            fun ?MODULE:t_dynamic_cast_messages_must_be_a_tuple_with_a_key/1,
            fun ?MODULE:t_dynamic_should_handle_random_cast/1,
            fun ?MODULE:t_dynamic_should_handle_multicast/1,
            fun ?MODULE:t_dynamic_should_not_handle_keyhash_cast/1,
            fun ?MODULE:t_non_dynamic_should_not_handle_unique/1,
            fun ?MODULE:t_config_with_one_worker_controller_target/1,
            fun ?MODULE:t_should_not_crash_on_random_data/1,
            fun ?MODULE:t_should_do_nothing_on_cast_with_no_workers/1
           ]]}.

t_start_stop([Pid | _]) ->
    ?assertNot(undefined == process_info(Pid)).

t_register_name([Pid | _]) ->
    ?assertEqual(Pid, whereis(?EPC_NAME)).

t_start_workers([Pid, WorkerSup | _]) ->
    ?assertEqual(ok, breeze_worker_controller:start_workers(Pid, 2)),
    ?assertEqual(2, length(supervisor:which_children(WorkerSup))).

t_start_workers_with_same_config([Pid, _WorkerSup, WorkerMod, MockModule|_]) ->
    WorkerConfig = [make_ref()],
    ?assertEqual(ok, breeze_worker_controller:start_workers(
		       Pid, 1, WorkerConfig)),
    ?assert(meck:called(WorkerMod, start_link,
                        [MockModule, WorkerConfig, []])).

t_pass_worker_config_to_worker_on_restart(
  [Pid, WorkerSup, WorkerMod, MockModule|_]) ->
    WorkerConfig = [make_ref()],
    ok = breeze_worker_controller:start_workers(Pid, 1, WorkerConfig),
    [Worker] = get_workers(WorkerSup),
    sync_exit(Worker),
    ?assertNot(meck:called(WorkerMod, start_link, [MockModule, [], []])),
    ?assertEqual(2, meck:num_calls(WorkerMod, start_link,
                                   [MockModule, WorkerConfig, []])).

t_should_not_allow_start_workers_once([Pid, WorkerSup | _ ]) ->
    ok = breeze_worker_controller:start_workers(Pid, 1),
    ?assertEqual({error, already_started},
                 breeze_worker_controller:start_workers(Pid, 1)),
    ?assert_workers(WorkerSup, 1).

t_restart_worker_when_it_crash([Pid, WorkerSup | _]) ->
    ok = breeze_worker_controller:start_workers(Pid, 1),
    [Worker] = get_workers(WorkerSup),
    sync_exit(Worker),
    ?assert_workers(WorkerSup, 1).

t_restarted_worker_should_keep_its_place([Pid, WorkerSup | _]) ->
    ok = breeze_worker_controller:start_workers(Pid, 2),
    Workers = get_workers(WorkerSup),
    Msg1 = {foo, 1},
    Msg2 = {bar, 2},
    ok = breeze_worker_controller:keyhash_cast(Pid, Msg1),
    ok = breeze_worker_controller:sync(Pid),
    [FirstWorker | _ ] = OrderedWorkers = order_workers(Workers, Msg1),
    assert_workers_process_func_is_called(OrderedWorkers, [1, 0], Msg1),
    sync_exit(FirstWorker),
    NewWorker = get_new_worker_pid(WorkerSup, Workers),
    OrderedWorkers2 = replace(OrderedWorkers, FirstWorker, NewWorker),
    keyhash_cast_and_assert(Pid, Msg1, OrderedWorkers2, [1, 0]),
    keyhash_cast_and_assert(Pid, Msg2, OrderedWorkers2, [0, 1]),
    ok.

t_multicast([Pid, WorkerSup, WorkerMod| _]) ->
    Msg = msg,
    ok = breeze_worker_controller:start_workers(Pid, 2),
    breeze_worker_controller:multicast(Pid, Msg),
    breeze_worker_controller:sync(Pid),
    assert_workers_are_called(WorkerMod, WorkerSup, process, [Msg]),
    ok.

t_sync([Pid, WorkerSup, WorkerMod | _]) ->
    ok = breeze_worker_controller:start_workers(Pid, 2),
    ?assertEqual(ok, breeze_worker_controller:sync(Pid)),
    assert_workers_are_called(WorkerMod, WorkerSup, sync),
    ok.

t_random_cast([Pid, WorkerSup | _]) ->
    meck:new(random, [passthrough, unstick]),
    ok = breeze_worker_controller:start_workers(Pid, 2),
    meck:sequence(random, uniform, 1, [1, 1, 2]),
    Workers = get_workers(WorkerSup),
    ok = breeze_worker_controller:random_cast(Pid, Msg = msg),
    ok = breeze_worker_controller:sync(Pid),

    OrderedWorkers = order_workers(Workers, Msg),
    assert_workers_random_and_process(OrderedWorkers, [1, 0], Msg),
    random_cast_and_assert(Pid, Msg, OrderedWorkers, [2, 0]),
    random_cast_and_assert(Pid, Msg, OrderedWorkers, [2, 1]),
    meck:unload(random).

t_keyhash_cast([Pid, WorkerSup | _]) ->
    ok = breeze_worker_controller:start_workers(Pid, 2),
    Workers = get_workers(WorkerSup),
    Msg1 = {foo, 1},
    Msg2 = {bar, 2},
    ok = breeze_worker_controller:keyhash_cast(Pid, Msg1),
    ok = breeze_worker_controller:sync(Pid),
    OrderedWorkers = order_workers(Workers, Msg1),
    assert_workers_process_func_is_called(OrderedWorkers, [1, 0], Msg1),

    keyhash_cast_and_assert(Pid, Msg1, OrderedWorkers, [2, 0]),
    keyhash_cast_and_assert(Pid, Msg2, OrderedWorkers, [0, 1]),
    ok.

t_keyhash_cast_error([Pid | _]) ->
    assert_invalid_messages(Pid, keyhash_cast).

t_enable_dynamic_workers([Pid, _WorkerSup | _]) ->
    ?assertEqual(ok, breeze_worker_controller:enable_dynamic_workers(Pid)),
    ?assertEqual(ok, breeze_worker_controller:enable_dynamic_workers(Pid)).

t_cant_activate_dynamic_workers_with_workers_started([Pid | _]) ->
    ok = breeze_worker_controller:start_workers(Pid, 1),
    ?assertEqual({error, workers_already_started},
		 breeze_worker_controller:enable_dynamic_workers(Pid)).

t_cant_start_workers_after_enabled_dynamic_workers([Pid | _ ]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    ?assertEqual({error, dynamic_workers},
		 breeze_worker_controller:start_workers(Pid, 1)).

t_start_dynamic_worker_when_doing_first_keycast([Pid, WorkerSup | _]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    breeze_worker_controller:dynamic_cast(Pid, {key1, data1}),
    breeze_worker_controller:sync(Pid),
    ?assert_workers(WorkerSup, 1).

t_start_dynamic_worker_should_set_targets(
  [Pid, _WorkerSup, WorkerMod, MockModule | _]) ->
    {OtherEpc, _WorkerSup2} = start(another_worker_controller, WorkerMod,
				    MockModule),
    Targets = [{OtherEpc, all}],
    ok = breeze_worker_controller:set_targets(Pid, Targets),
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    breeze_worker_controller:dynamic_cast(Pid, {key1, data1}),
    breeze_worker_controller:sync(Pid),
    ?assertEqual(1, meck:num_calls(WorkerMod, start_link,
                                   [MockModule, [], [{targets, Targets}]])),
    breeze_worker_controller:stop(OtherEpc).

t_should_send_message_to_started_worker([Pid, WorkerSup, WorkerMod | _]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    Msg = {key1, data1},
    breeze_worker_controller:dynamic_cast(Pid, Msg),
    breeze_worker_controller:sync(Pid),
    [WorkerPid] = get_workers(WorkerSup),
    ?assertEqual(1, meck:num_calls(WorkerMod, process, [WorkerPid, Msg])).

t_should_not_start_new_worker_with_same_key([Pid, WorkerSup, WorkerMod | _]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    Msg1 = {key1, data1},
    Msg2 = {key1, data2},
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:dynamic_cast(Pid, Msg2),
    breeze_worker_controller:sync(Pid),
    ?assert_workers(WorkerSup, 1),
    [WorkerPid] = get_workers(WorkerSup),
    ?assertEqual(2, meck:num_calls(WorkerMod, process, [WorkerPid, Msg1])),
    ?assertEqual(1, meck:num_calls(WorkerMod, process, [WorkerPid, Msg2])).

t_should_remember_the_old_dynamic_workers([Pid, WorkerSup, WorkerMod | _]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    Msg1 = {key1, data1},
    Msg2 = {key2, data2},
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:dynamic_cast(Pid, Msg2),
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:sync(Pid),
    ?assertEqual(2, meck:num_calls(WorkerMod, start_link, '_')),
    [WorkerPid1, WorkerPid2] = get_workers(WorkerSup),
    ?assertEqual(2, meck:num_calls(WorkerMod, process, [WorkerPid1, Msg1])),
    ?assertEqual(1, meck:num_calls(WorkerMod, process, [WorkerPid2, Msg2])).

t_dynamic_workers_should_be_restarted_if_they_crash(
  [Pid, WorkerSup, WorkerMod | _ ]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    Msg1 = {key1, data1},
    Msg2 = {key2, data2},
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:dynamic_cast(Pid, Msg2),
    breeze_worker_controller:sync(Pid),
    Workers = [WorkerPid1, WorkerPid2] = get_workers(WorkerSup),
    sync_exit(WorkerPid1),
    ?assertEqual(3, meck:num_calls(WorkerMod, start_link, '_')),
    ?assert_workers(WorkerSup, 2),
    NewWorker = get_new_worker_pid(WorkerSup, Workers),
    breeze_worker_controller:dynamic_cast(Pid, Msg1),
    breeze_worker_controller:sync(Pid),

    ?assertEqual(1, meck:num_calls(WorkerMod, process, [NewWorker, Msg1])),
    ?assertEqual(1, meck:num_calls(WorkerMod, process, [WorkerPid2, Msg2])),

    breeze_worker_controller:dynamic_cast(Pid, Msg2),
    breeze_worker_controller:sync(Pid),
    ?assertEqual(1, meck:num_calls(WorkerMod, process, [NewWorker, Msg1])),
    ?assertEqual(2, meck:num_calls(WorkerMod, process, [WorkerPid2, Msg2])).

t_dynamic_cast_messages_must_be_a_tuple_with_a_key([Pid | _]) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    assert_invalid_messages(Pid, dynamic_cast).

t_dynamic_should_handle_random_cast([Pid, _WorkerSup, WorkerMod | _]) ->
    Cast = random_cast,
    assert_cast_after_dynamic_cast(Pid, Cast, WorkerMod, _ExpectCalls = 2).

t_dynamic_should_handle_multicast([Pid, _WorkerSup, WorkerMod | _]) ->
    Cast = multicast,
    assert_cast_after_dynamic_cast(Pid, Cast, WorkerMod, _ExpectCalls = 2).

t_dynamic_should_not_handle_keyhash_cast([Pid, _WorkerSup, WorkerMod | _]) ->
    Cast = keyhash_cast,
    assert_cast_after_dynamic_cast(Pid, Cast, WorkerMod, _ExpectCalls = 1).

t_non_dynamic_should_not_handle_unique([Pid, WorkerSup, WorkerMod | _ ]) ->
    breeze_worker_controller:dynamic_cast(Pid, {key1, data1}),
    ?assert_workers(WorkerSup, 0),
    ?assertNot(meck:called(WorkerMod, process, '_')).

t_config_with_one_worker_controller_target(
  [Pid1, _WorkerSup1, WorkerMod, MockModule | _]) ->
    {OtherEpc, _WorkerSup2} =
	start(another_worker_controller, WorkerMod, MockModule),
    Targets = [{OtherEpc, all}],
    ok = breeze_worker_controller:set_targets(Pid1, Targets),
    ok = breeze_worker_controller:start_workers(Pid1, 1),
    ?assert(meck:validate(WorkerMod)),
    ?assertEqual(1, meck:num_calls(WorkerMod, start_link,
                                   [MockModule, [], [{targets, Targets}]])),
    breeze_worker_controller:stop(OtherEpc).

t_should_not_crash_on_random_data([Pid |_]) ->
    RandomData = {make_ref(), now(), foo, [self()]},
    Pid ! RandomData,
    gen_server:cast(Pid, RandomData),
    ?assertEqual({error, {invalid_request, RandomData}},
                 gen_server:call(Pid, RandomData)).

t_should_do_nothing_on_cast_with_no_workers([Pid | _]) ->
    Msg = {foo, 1},
    ?assertEqual(ok, breeze_worker_controller:multicast(Pid, Msg)),
    ?assertEqual(ok, breeze_worker_controller:random_cast(Pid, Msg)),
    ?assertEqual(ok, breeze_worker_controller:keyhash_cast(Pid, Msg)),
    ?assertEqual(ok, breeze_worker_controller:sync(Pid)).

should_seed_at_startup_test() ->
    meck:new(random, [passthrough, unstick]),
    S = setup(),
    ?assertEqual(1, meck:num_calls(random, seed, ['_', '_', '_'])),
    teardown(S),
    meck:unload(random).

% Assert functions
assert_workers_are_called(WorkerMod, WorkerSup, Func) ->
    assert_workers_are_called(WorkerMod, WorkerSup, Func, []).
assert_workers_are_called(WorkerMod, WorkerSup, Func, ExtraArgs) ->
    lists:foreach(fun(Pid) ->
                          ?assert(meck:called(WorkerMod, Func,
					      [Pid] ++ ExtraArgs))
                  end, get_workers(WorkerSup)).

random_cast_and_assert(Pid, Msg, OrderedWorkers, ExpectedList) ->
    ok = breeze_worker_controller:random_cast(Pid, Msg),
    ok = breeze_worker_controller:sync(Pid),
    assert_workers_random_and_process(OrderedWorkers, ExpectedList, Msg).

keyhash_cast_and_assert(Pid, Msg, OrderedWorkers, ExpectedList) ->
    ok = breeze_worker_controller:keyhash_cast(Pid, Msg),
    ok = breeze_worker_controller:sync(Pid),
    assert_workers_process_func_is_called(OrderedWorkers, ExpectedList, Msg).


assert_workers_process_func_is_called(Workers, ExpectedList, Msg) ->
    lists:foreach(
      fun({Worker, Expected}) ->
              ?assertEqual(Expected,
			   meck:num_calls(breeze_processing_worker, process,
					  [Worker, Msg]))
      end, lists:zip(Workers, ExpectedList)).

assert_workers_random_and_process(Workers, ExpectedList, Msg) ->
    NumberOfWorkers = length(Workers),
    ExpectedRandomUniformCalls = lists:sum(ExpectedList),
    ?assertEqual(ExpectedRandomUniformCalls, meck:num_calls(
                   random, uniform, [NumberOfWorkers])),
    assert_workers_process_func_is_called(Workers, ExpectedList, Msg).

assert_cast_after_dynamic_cast(Pid, CastFunc, WorkerMod, ExpectedCalls) ->
    ok = breeze_worker_controller:enable_dynamic_workers(Pid),
    Msg = {key1, data1},
    breeze_worker_controller:dynamic_cast(Pid, Msg), % Create a worker
    breeze_worker_controller:CastFunc(Pid, Msg),
    breeze_worker_controller:sync(Pid),
    ?assertEqual(ExpectedCalls, meck:num_calls(WorkerMod, process, '_')).

assert_invalid_messages(Pid, Func) ->
    Msg1 = foo,
    Msg2 = {},
    ?assert_invalid_message(Pid, Func, Msg1),
    ?assert_invalid_message(Pid, Func, Msg2).

% Setup/teardown functions
% TODO: make WorkerMod into a parameter
setup() ->
    WorkerMod = breeze_processing_worker,
    meck:new(breeze_processing_worker, [passthrough]),
    MockModule = create_behaviour_stub(WorkerMod),
    {Pid, WorkerSup} = start(?EPC_NAME, WorkerMod, MockModule),
    [Pid, WorkerSup, WorkerMod, MockModule].

create_behaviour_stub(breeze_processing_worker) ->
    MockModule = processing_worker_mock,
    ok = meck:new(MockModule),
    meck:expect(MockModule, init, fun(_) -> {ok, []} end),
    meck:expect(MockModule, process,
                fun(_Msg, _EmitFun, State) ->
                        {ok, State}
                end),
    meck:expect(MockModule, terminate, fun(_, State) -> State end),
    MockModule.

start(Name, WorkerMod, WorkerCallback) ->
    {ok, WorkerSup} = breeze_worker_sup:start_link(WorkerMod, WorkerCallback),
    {ok, Pid} = breeze_worker_controller:start_link(Name, WorkerMod, WorkerSup),
    {Pid, WorkerSup}.

teardown([Pid, WorkerSup, WorkerMod, MockModule]) ->
    breeze_worker_controller:stop(Pid),
    breeze_worker_sup:stop(WorkerSup),
    ok = meck:unload(MockModule),
    ok = meck:unload(WorkerMod).

% Getters
get_workers(WorkerSup) ->
    Children = supervisor:which_children(WorkerSup),
    lists:map(fun(Child) -> element(2, Child) end, Children).


% Other help methods

% Put the worker that receive the first process call first in the list
order_workers(Workers, Msg) ->
    case meck:num_calls(breeze_processing_worker, process,
			[hd(Workers), Msg]) of
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

get_new_worker_pid(WorkerSup, OldWorkers) ->
    NewWorkers = get_workers(WorkerSup),
    [NewWorker] = NewWorkers -- OldWorkers,
    NewWorker.
