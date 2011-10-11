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

-module(epa_master_tests).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    {ok, Pid} = epa_master:start_link([]),
    ?assertNot(undefined == process_info(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(epa_master)),
    Ref = monitor(process, Pid),
    ok = epa_master:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(epa_master)).

read_simple_config_and_start_epc_consumer_test() ->
    test_read_simple_config_and_start_epc(consumer), ok.

read_simple_config_and_start_epc_producer_test() ->
    test_read_simple_config_and_start_epc(producer), ok.

test_read_simple_config_and_start_epc(WorkerType) ->
    test_read_simple_config_and_start_epc(WorkerType,
                                          worker_mod(WorkerType),
                                          callback_mod(WorkerType)).

test_read_simple_config_and_start_epc(WorkerType, WorkerMod, WorkerCallback) ->
    {WorkerSup, [EpcPid|_]} = mock(),

    NumberOfWorkers = 2,
    Name = dummy,

    Config = [{topology, [{Name, WorkerType, WorkerCallback, NumberOfWorkers,
                           []}]}],

    {ok, _Pid} = epa_master:start_link(Config),

    ?assert(meck:called(pc_supersup, start_worker_sup,
                        [WorkerMod, WorkerCallback])),
    ?assert(meck:called(epc_sup, start_epc, [Name, WorkerMod, WorkerSup])),
    ?assertNot(meck:called(epc, set_targets, [])),
    ?assert(meck:called(epc, start_workers, [EpcPid, NumberOfWorkers])),
    teardown().

worker_mod(producer) ->
    eg;
worker_mod(consumer) ->
    epw.

callback_mod(producer) ->
    eg_dummy;
callback_mod(consumer) ->
    epw_dummy.

read_config_with_two_connected_epcs_test() ->
    {WorkerSup, [EpcPid1, EpcPid2 | _]} = mock(),
    SenderCallback = sender_callback,
    ReceiverCallback = receiver_callback,
    SenderWorkers = 2,
    ReceiverWorkers = 3,
    WorkerType = consumer,
    WorkerMod = worker_mod(WorkerType),
    mock_epw_callback(SenderCallback),
    mock_epw_callback(ReceiverCallback),
    Config = [{topology, [{sender, WorkerType, SenderCallback, SenderWorkers,
                           [{receiver, all}]},
                          {receiver, WorkerType, ReceiverCallback,
                           ReceiverWorkers, []}
                         ]
              }],
    {ok, _Pid} = epa_master:start_link(Config),

    ?assert(meck:called(pc_supersup, start_worker_sup,
                        [WorkerMod, SenderCallback])),
    ?assert(meck:called(pc_supersup, start_worker_sup,
                        [WorkerMod, ReceiverCallback])),
    ?assertEqual(1, meck_improvements:calls(epc_sup, start_epc,
                                            [sender, WorkerMod, WorkerSup])),
    ?assertEqual(1, meck_improvements:calls(epc_sup, start_epc,
                                            [receiver, WorkerMod, WorkerSup])),
    ?assert(meck:called(epc, set_targets, [EpcPid1, [{EpcPid2, all}]])),
    ?assert(meck:called(epc, start_workers, [EpcPid1, SenderWorkers])),
    ?assert(meck:called(epc, start_workers, [EpcPid2, ReceiverWorkers])),
    meck:unload(SenderCallback),
    meck:unload(ReceiverCallback),
    teardown().

get_epc_by_name_test() ->
    {_WorkerSup, [EpcPid|_]} = mock(),
    WorkerName = dummy,
    InvalidWorkerName = invalid_name,

    Config = [{topology, [{WorkerName, consumer, epw_dummy, 1, []}]}],

    {ok, _Pid} = epa_master:start_link(Config),
    ?assertEqual({error, {not_found, InvalidWorkerName}},
		  epa_master:get_controller(InvalidWorkerName)),
    ?assertEqual({ok, EpcPid}, epa_master:get_controller(WorkerName)),
    teardown().

should_not_crash_on_random_data_to_gen_server_callbacks_test() ->
    {ok, Pid} = epa_master:start_link([]),
    RandomData = {make_ref(), now(), foo, [self()]},
    gen_server:cast(Pid, RandomData),
    Pid ! RandomData,
    gen_server:call(Pid, RandomData),
    epa_master:stop().


should_check_topology_test() ->
    meck:new(config_validator),
    Error = {error, some_error},
    meck:expect(config_validator, check_config, 1, Error),
    Config = [{topology, [foo]}],
    ?assertEqual(Error, epa_master:start_link(Config)),
    ?assert(meck:called(config_validator, check_config, [Config])),
    meck:unload(config_validator),
    ok.

%% Internal functions
mock() ->
    meck:new(pc_supersup),
    meck:new(epc_sup),
    meck:new(epc),
    WorkerSup = create_pid(),
    EpcPids = lists:map(fun(_) -> create_pid() end, lists:seq(1, 3)),
    StartEpcRetVal = lists:zip(lists:duplicate(length(EpcPids), ok), EpcPids),
    meck:expect(pc_supersup, start_worker_sup, 2, {ok, WorkerSup}),
    meck:sequence(epc_sup, start_epc, 3, StartEpcRetVal),
    meck:expect(epc, set_targets, 2, ok),
    meck:expect(epc, start_workers, 2, ok),
    {WorkerSup, EpcPids}.

mock_epw_callback(CallbackModule) ->
    meck:new(CallbackModule),
    meck:expect(CallbackModule, init, fun(State) -> {ok, State} end),
    meck:expect(CallbackModule, process,
		fun(_Msg, _EmitFun, State) -> {ok, State} end),
    meck:expect(CallbackModule, terminate, fun(_Reason, State) -> State end).

teardown() ->
    unload_mocks(),
    epa_master:stop().

unload_mocks() ->
    meck:unload(epc),
    meck:unload(epc_sup),
    meck:unload(pc_supersup).

create_pid() ->
     spawn(fun() -> timer:sleep(infinity) end).
