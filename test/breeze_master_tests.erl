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

-module(breeze_master_tests).

-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

start_stop_test() ->
    {ok, Pid} = breeze_master:start_link([]),
    ?assertNot(undefined == process_info(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(breeze_master)),
    Ref = monitor(process, Pid),
    ok = breeze_master:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(breeze_master)).

should_check_topology_test() ->
    test_config_check(start_link).

tests_with_mock_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} ||
      T <- [
	    fun ?MODULE:t_should_not_crash_on_random_data/1,
	    fun ?MODULE:t_should_check_configuration_before_set/1,
	    fun ?MODULE:t_read_simple_config_and_start_epc_consumer/1,
	    fun ?MODULE:t_read_simple_config_and_start_epc_producer/1,
	    fun ?MODULE:t_set_and_start_configuration/1,
	    fun ?MODULE:t_should_not_set_configuration_with_a_configuration/1,
	    fun ?MODULE:t_consumers_should_be_started_before_producers/1,
	    fun ?MODULE:t_read_config_with_two_connected_epcs/1,
	    fun ?MODULE:t_read_config_with_dynamic_worker/1,
	    fun ?MODULE:t_read_config_with_two_epcs_with_worker_config/1,
	    fun ?MODULE:t_get_epc_by_name/1
	   ]]}.

t_should_not_crash_on_random_data(_) ->
    {ok, Pid} = breeze_master:start_link([]),
    RandomData = {make_ref(), now(), foo, [self()]},
    gen_server:cast(Pid, RandomData),
    Pid ! RandomData,
    ?assertEqual({error, {invalid_request, RandomData}},
		 gen_server:call(Pid, RandomData)).

t_should_check_configuration_before_set(_) ->
    {ok, _Pid} = breeze_master:start_link([]),
    test_config_check(set_and_start_configuration).

t_read_simple_config_and_start_epc_consumer(Setup) ->
    test_read_simple_config_and_start_epc(Setup, consumer).

t_read_simple_config_and_start_epc_producer(Setup) ->
    test_read_simple_config_and_start_epc(Setup, producer).

% TODO: code duplication
t_set_and_start_configuration({WorkerSup, [EpcPid|_]}) ->
    NumberOfWorkers = 2,
    Name = dummy,
    Config0 = [],
    WorkerType = consumer,
    WorkerCallback = callback_mod(WorkerType),
    WorkerMod = breeze_master:get_worker_mode_by_type(WorkerType),
    Config1 = append_worker(Config0, Name, WorkerType, WorkerCallback,
                            NumberOfWorkers),

    {ok, _Pid} = breeze_master:start_link([]),
    ?assertEqual(ok, breeze_master:set_and_start_configuration(Config1)),
    ?assert(meck:called(breeze_pc_supersup, start_worker_sup,
                        [WorkerMod, WorkerCallback])),
    ?assert(meck:called(breeze_epc_sup, start_epc,
			[Name, WorkerMod, WorkerSup])),
    ?assertNot(meck:called(breeze_epc, set_targets, [EpcPid, []])),
    ?assert(meck:called(breeze_epc, start_workers,
			[EpcPid, NumberOfWorkers, []])).

t_should_not_set_configuration_with_a_configuration(_) ->
    NumberOfWorkers = 2,
    Name = dummy,
    Config0 = [],
    WorkerType = consumer,
    WorkerCallback = callback_mod(WorkerType),
    Config1 = append_worker(Config0, Name, WorkerType, WorkerCallback,
                            NumberOfWorkers),

    {ok, _Pid} = breeze_master:start_link(Config1),

    ?assertEqual({error, already_have_a_configuration},
		 breeze_master:set_and_start_configuration(Config1)).

t_consumers_should_be_started_before_producers(
  {WorkerSup, [EpcPid1, EpcPid2, EpcPid3|_]}) ->
    Config0 = [],
    Config1 = append_worker(Config0, consumer1, consumer, epw_dummy, 3),
    Config2 = append_worker(Config1, producer, producer, eg_dummy, 1,
                            [{consumer1, all}, {consumer2, all}]),
    Config3 = append_worker(Config2, consumer2, consumer, epw_dummy, 2,
                            [{consumer1, all}]),
    {ok, _Pid} = breeze_master:start_link(Config3),
    EpcSupHistory = clean_meck_history(meck:history(breeze_epc_sup)),

    ExpectedEpcSupHistory = [{breeze_epc_sup,start_epc,
			      [consumer1,breeze_epw,WorkerSup]},
                             {breeze_epc_sup,start_epc,
			      [consumer2,breeze_epw,WorkerSup]},
                             {breeze_epc_sup,start_epc,
			      [producer,breeze_eg,WorkerSup]}],
    ?assertEqual(ExpectedEpcSupHistory, EpcSupHistory),

    EpcHistory = clean_meck_history(meck:history(breeze_epc)),
    ExpectedEpcHistory = [{breeze_epc,set_targets,[EpcPid2,[{EpcPid1,all}]]},
                          {breeze_epc, start_workers,[EpcPid1, 3, []]},
                          {breeze_epc, start_workers,[EpcPid2, 2, []]},
                          {breeze_epc, set_targets,
                           [EpcPid3,[{EpcPid1,all},{EpcPid2,all}]]},
                          {breeze_epc, start_workers,[EpcPid3, 1, []]}],
    ?assertEqual(ExpectedEpcHistory, EpcHistory).

t_read_config_with_two_connected_epcs({WorkerSup, [EpcPid1, EpcPid2 | _]}) ->
    SenderCallback = sender_callback,
    ReceiverCallback = receiver_callback,
    Callbacks = [SenderCallback, ReceiverCallback],
    SenderWorkers = 2,
    ReceiverWorkers = 3,
    WorkerType = consumer,
    WorkerMod = breeze_master:get_worker_mode_by_type(WorkerType),
    mock_callbacks(Callbacks),
    Config0 = [],
    Config1 = append_worker(Config0, sender, WorkerType, SenderCallback,
                            SenderWorkers, [{receiver, all}]),
    Config2 = append_worker(Config1, receiver, WorkerType, ReceiverCallback,
                            ReceiverWorkers),
    {ok, _Pid} = breeze_master:start_link(Config2),

    ?assert(meck:called(breeze_pc_supersup, start_worker_sup,
                        [WorkerMod, SenderCallback])),
    ?assert(meck:called(breeze_pc_supersup, start_worker_sup,
                        [WorkerMod, ReceiverCallback])),
    ?assertEqual(1, meck:num_calls(breeze_epc_sup, start_epc,
                                   [sender, WorkerMod, WorkerSup])),
    ?assertEqual(1, meck:num_calls(breeze_epc_sup, start_epc,
                                   [receiver, WorkerMod, WorkerSup])),
    ?assert(meck:called(breeze_epc, set_targets, [EpcPid1, [{EpcPid2, all}]])),
    ?assert(meck:called(breeze_epc, start_workers,
			[EpcPid1, SenderWorkers, []])),
    ?assert(meck:called(breeze_epc, start_workers,
			[EpcPid2, ReceiverWorkers, []])),
    unload_callbacks(Callbacks).

t_read_config_with_dynamic_worker({_WorkerSup, [EpcPid1, EpcPid2 | _]}) ->
    SenderCallback = sender_callback,
    ReceiverCallback = receiver_callback,
    Callbacks = [SenderCallback, ReceiverCallback],
    SenderWorkers = 2,
    ReceiverWorkers = dynamic,
    WorkerType = consumer,
    TargetType = dynamic,
    mock_callbacks(Callbacks),
    Config0 = [],
    Config1 = append_worker(Config0, sender, WorkerType, SenderCallback,
                            SenderWorkers, [{receiver, TargetType}]),
    Config2 = append_worker(Config1, receiver, WorkerType, ReceiverCallback,
                            ReceiverWorkers),
    {ok, _Pid} = breeze_master:start_link(Config2),

    ?assert(meck:called(breeze_epc, set_targets,
			[EpcPid1, [{EpcPid2, TargetType}]])),
    ?assert(meck:called(breeze_epc, start_workers,
			[EpcPid1, SenderWorkers, []])),
    ?assertNot(meck:called(breeze_epc, start_workers,
			   [EpcPid2, ReceiverWorkers, []])),
    ?assert(meck:called(breeze_epc, enable_dynamic_workers, [EpcPid2])),
    unload_callbacks(Callbacks).

t_read_config_with_two_epcs_with_worker_config(
  {_WorkerSup, [EpcPid1, EpcPid2 | _]}) ->
    SenderConfig = [sender_config],
    ReceiverConfig = [receiver_config],
    SenderWorkers = 1,
    ReceiverWorkers = 2,
    Config0 = [],
    Config1 = append_worker(Config0, sender, producer, eg_dummy, SenderWorkers),
    Config2 = append_worker(Config1, receiver, consumer, epw_dummy,
			    ReceiverWorkers),
    Config3 = append_worker_config(Config2, sender, SenderConfig),
    Config4 = append_worker_config(Config3, receiver, ReceiverConfig),

    {ok, _Pid} = breeze_master:start_link(Config4),
    ?assertNot(meck:called(breeze_epc, start_workers,
			   [EpcPid1, ReceiverWorkers, []])),
    ?assertNot(meck:called(breeze_epc, start_workers,
			   [EpcPid2, SenderWorkers, []])),

    ?assert(meck:called(breeze_epc, start_workers,
                        [EpcPid1, ReceiverWorkers, ReceiverConfig])),
    ?assert(meck:called(breeze_epc, start_workers,
                        [EpcPid2, SenderWorkers, SenderConfig])).

t_get_epc_by_name({_WorkerSup, [EpcPid|_]}) ->
    WorkerName = dummy,
    InvalidWorkerName = invalid_name,
    Config0 = [],
    Config1 = append_worker(Config0, WorkerName, consumer, epw_dummy, 1),

    {ok, _Pid} = breeze_master:start_link(Config1),
    ?assertEqual({error, {not_found, InvalidWorkerName}},
                 breeze_master:get_controller(InvalidWorkerName)),
    ?assertEqual({ok, EpcPid}, breeze_master:get_controller(WorkerName)).

% parameterised tests
test_config_check(Func) ->
    meck:new(breeze_config_validator),
    Error = {error, some_error},
    meck:expect(breeze_config_validator, check_config, 1, Error),
    Config = [{topology, [foo]}],
    ?assertEqual(Error, breeze_master:Func(Config)),
    ?assert(meck:called(breeze_config_validator, check_config, [Config])),
    meck:unload(breeze_config_validator).

test_read_simple_config_and_start_epc(Setup, WorkerType) ->
    test_read_simple_config_and_start_epc(Setup,
      WorkerType, breeze_master:get_worker_mode_by_type(WorkerType),
      callback_mod(WorkerType)).

test_read_simple_config_and_start_epc({WorkerSup, [EpcPid|_]}, WorkerType,
				      WorkerMod, WorkerCallback) ->
    NumberOfWorkers = 2,
    Name = dummy,
    Config0 = [],
    Config1 = append_worker(Config0, Name, WorkerType, WorkerCallback,
                            NumberOfWorkers),

    {ok, _Pid} = breeze_master:start_link(Config1),

    ?assert(meck:called(breeze_pc_supersup, start_worker_sup,
                        [WorkerMod, WorkerCallback])),
    ?assert(meck:called(breeze_epc_sup, start_epc,
			[Name, WorkerMod, WorkerSup])),
    ?assertNot(meck:called(breeze_epc, set_targets, [EpcPid, []])),
    ?assert(meck:called(breeze_epc, start_workers,
			[EpcPid, NumberOfWorkers, []])).

%% Internal functions
setup() ->
    meck:new(breeze_pc_supersup),
    meck:new(breeze_epc_sup),
    meck:new(breeze_epc),
    WorkerSup = create_pid(),
    EpcPids = lists:map(fun(_) -> create_pid() end, lists:seq(1, 3)),
    StartEpcRetVal = lists:zip(lists:duplicate(length(EpcPids), ok), EpcPids),
    meck:expect(breeze_pc_supersup, start_worker_sup, 2, {ok, WorkerSup}),
    meck:sequence(breeze_epc_sup, start_epc, 3, StartEpcRetVal),
    meck:expect(breeze_epc, set_targets, 2, ok),
    meck:expect(breeze_epc, start_workers, 3, ok),
    meck:expect(breeze_epc, enable_dynamic_workers, 1, ok),
    {WorkerSup, EpcPids}.

mock_callbacks(Callbacks) ->
    lists:foreach(fun(Callback) -> mock_epw_callback(Callback) end, Callbacks).

mock_epw_callback(CallbackModule) ->
    meck:new(CallbackModule),
    meck:expect(CallbackModule, init, fun(State) -> {ok, State} end),
    meck:expect(CallbackModule, process,
                fun(_Msg, _EmitFun, State) -> {ok, State} end),
    meck:expect(CallbackModule, terminate, fun(_Reason, State) -> State end).

teardown(_) ->
    unload_mocks(),
    breeze_master:stop().

unload_callbacks(Callbacks) ->
    lists:foreach(fun(Callback) -> meck:unload(Callback) end, Callbacks).

unload_mocks() ->
    meck:unload(breeze_epc),
    meck:unload(breeze_epc_sup),
    meck:unload(breeze_pc_supersup).

create_pid() ->
     spawn(fun() -> timer:sleep(infinity) end).

clean_meck_history(MeckHistory) ->
    lists:map(fun(Call) -> element(2, Call) end, MeckHistory).

append_worker(Config, Name, WorkerType, Cb, NumWorkers) when
      is_list(Config)->
    append_worker(Config, Name, WorkerType, Cb, NumWorkers, _Targets = []).

append_worker(Config, Name, WorkerType, Cb, NumWorkers, Targets) ->
    Topology0 = proplists:get_value(topology, Config, []),
    Topology1 = Topology0 ++ [{Name, WorkerType, Cb, NumWorkers, Targets}],
    merge([{topology, Topology1}], Config).

append_worker_config(Config, WorkerName, DistType) ->
    WorkerConfigs0 = proplists:get_value(worker_config, Config, []),
    WorkerConfigs1 = WorkerConfigs0 ++ [{WorkerName, DistType}],
    merge([{worker_config, WorkerConfigs1}], Config).

merge(PropList1, PropList2) ->
    lists:keymerge(1, lists:keysort(1, PropList1), lists:keysort(1, PropList2)).

callback_mod(producer) ->
    eg_dummy;
callback_mod(consumer) ->
    epw_dummy.
