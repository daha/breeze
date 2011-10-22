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

-module(config_validator_tests).

-include_lib("eunit/include/eunit.hrl").

valid_topology_test() ->
    Topology1 = [{topology, [consumer_cb(name, 1)]}],
    Topology2 = [{topology, [producer_db(name, 2)]}],
    Topology3 = [{topology, [consumer_cb(name1, 3, [{name2, all}]),
                             consumer_cb(name2, 4)]}],
    Topology4 = [{topology, [consumer_cb(name1, 5, [{name2, random}]),
                             consumer_cb(name2, 6)]}],
    Topology5 = [{topology, [consumer_cb(name1, 7, [{name2, keyhash}]),
                             consumer_cb(name2, 8)]}],
    Topology6 = [{topology, [consumer_cb(name1, 9,
                                      [{name2, keyhash}, {name3, all}]),
                             consumer_cb(name2, 10),
                             consumer_cb(name3, 11)]}],
    Topology7 = [{topology, [producer_db(name1, 12, [{name2, random}]),
                             consumer_cb(name2, 13)]}],
    Topology8 = [{topology, [producer_db(name1, 14, [{name2, dynamic}]),
                             consumer_cb(name2, dynamic)]}],
    ?assertEqual(ok, config_validator:check_config(Topology1)),
    ?assertEqual(ok, config_validator:check_config(Topology2)),
    ?assertEqual(ok, config_validator:check_config(Topology3)),
    ?assertEqual(ok, config_validator:check_config(Topology4)),
    ?assertEqual(ok, config_validator:check_config(Topology5)),
    ?assertEqual(ok, config_validator:check_config(Topology6)),
    ?assertEqual(ok, config_validator:check_config(Topology7)),
    ?assertEqual(ok, config_validator:check_config(Topology8)),
    ok.

invalid_topology_syntax_check_test() ->
    InvalidTopology1 = [{topology, [foo]}],
    InvalidTopology2 = [{topology, [{foo, consumer, bar, 1}]}],
    InvalidTopology3 = [{topology, [{foo, consumer, bar, 1, [], []}]}],
    InvalidTopology4 = [{topology, [consumer(1, bar, 1, foo)]}],
    InvalidTopology5 = [{topology, [worker(foo, 2, bar, 1, foo)]}],
    InvalidTopology6 = [{topology, [consumer(foo, 3, 1, foo)]}],
    InvalidTopology7 = [{topology, [consumer(foo, bar, baz)]}],

    ?assertEqual({error, {invalid_topology_syntax, foo}},
                 config_validator:check_config(InvalidTopology1)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, consumer, bar, 1}}},
                 config_validator:check_config(InvalidTopology2)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, consumer, bar, 1, [], []}}},
                 config_validator:check_config(InvalidTopology3)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {1, consumer, bar, 1, foo}}},
                 config_validator:check_config(InvalidTopology4)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, 2, bar, 1, foo}}},
                 config_validator:check_config(InvalidTopology5)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, consumer, 3, 1, foo}}},
                 config_validator:check_config(InvalidTopology6)),
    ?assertEqual({error, {invalid_topology_syntax,
                          consumer(foo, bar, baz)}},
                 config_validator:check_config(InvalidTopology7)).

invalid_topology_target_syntax_check_test() ->
    InvalidTopology1 = [{topology, [consumer(foo, bar, 1, foo)]}],
    InvalidTopology2 = [{topology, [consumer(foo, bar, 1, [foo])]}],
    InvalidTopology3 = [{topology, [consumer(foo, bar, 1, [{foo}])]}],
    InvalidTopology4 = [{topology, [consumer(foo, bar, 1, [{foo, bar, baz}])]}],
    InvalidTopology5 = [{topology, [consumer(foo, bar, 1, [{4, bar}])]}],
    InvalidTopology6 = [{topology, [consumer(foo, bar, 1, [{foo, 5}])]}],

    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, consumer, bar, 1, foo}}},
                 config_validator:check_config(InvalidTopology1)),
    ?assertEqual({error, {invalid_topology_target_syntax, foo}},
                 config_validator:check_config(InvalidTopology2)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo}}},
                 config_validator:check_config(InvalidTopology3)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo, bar, baz}}},
                 config_validator:check_config(InvalidTopology4)),
    ?assertEqual({error, {invalid_topology_target_syntax, {4, bar}}},
                 config_validator:check_config(InvalidTopology5)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo, 5}}},
                 config_validator:check_config(InvalidTopology6)).

invalid_topology_target_references_test() ->
    InvalidTargetRef1 = [{topology, [consumer(name, bar, 1, [{name, all}])]}],
    InvalidTargetRef2 = [{topology, [consumer(name, bar, 1,
                                      [{invalid_name, all}])]}],
    InvalidTargetRef3 = [{topology, [consumer(name1, bar, 1),
                                     consumer(name2, bar, 1,
                                              [{name1, all},
                                               {invalid_name, all}])]}],
    ?assertEqual({error, {invalid_target_ref, name}},
                 config_validator:check_config(InvalidTargetRef1)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 config_validator:check_config(InvalidTargetRef2)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 config_validator:check_config(InvalidTargetRef3)),
    ok.

invalid_topology_target_ref_type_test() ->
    InvalidTargetRefType = [{topology, [consumer(name1, bar, 1),
                                        consumer(name2, bar, 1,
                                                 [{name1, foo}])]}],
    ?assertEqual({error, {invalid_target_ref_type, foo}},
                 config_validator:check_config(InvalidTargetRefType)).

valid_topology_target_ref_type_test() ->
    ValidTargetRefType1 =
        [{topology, [consumer_cb(name1, 1),
                     consumer_cb(name2, 1, [{name1, all}])]}],
    ValidTargetRefType2 =
        [{topology, [consumer_cb(name1, 1),
                     consumer_cb(name2, 1, [{name1, random}])]}],
    ValidTargetRefType3 =
        [{topology, [consumer_cb(name1, 1),
                     consumer_cb(name2, 1, [{name1, keyhash}])]}],
    ValidTargetRefType4 =
        [{topology, [producer_db(name1, 1, [{name2, keyhash}]),
                     consumer_cb(name2, 1)]}],
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType1)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType2)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType3)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType4)),
    ok.

invalid_topology_duplicated_worker_name_test() ->
    DupName = [{topology, [consumer(name, bar, 1),
                           consumer(name, bar, 1)]}],
    ?assertEqual({error, duplicated_worker_name},
                 config_validator:check_config(DupName)).

invalid_topology_worker_type_test() ->
    InvalidWorkerType = [{topology, [worker(name, foo, bar, 1, [])]}],
    ?assertEqual({error, {invalid_worker_type, foo}},
                 config_validator:check_config(InvalidWorkerType)).

invalid_topology_worker_callback_module_test() ->
    InvalidWorkerCallbackModule =
        [{topology, [consumer(name, invalid_callback, 1)]}],
    ?assertEqual({error, {invalid_worker_callback_module, invalid_callback}},
                 config_validator:check_config(InvalidWorkerCallbackModule)).

dynamic_target_must_be_dynamic_test() ->
    NotDynamicWorker = [{topology,
                         [consumer_cb(name1, 1, [{name2, dynamic}]),
                          consumer_cb(name2, 1)]}],
    ?assertEqual({error, {dynamic_target_must_have_dynamic_workers, name2}},
                 config_validator:check_config(NotDynamicWorker)).

keyhash_targets_must_not_be_dynamic_test() ->
    InvalidTopology = [{topology,
                        [consumer_cb(name1, 1, [{name2, keyhash}]),
                         consumer_cb(name2, dynamic)]}],
    ?assertEqual({error, {keyhash_targets_must_not_be_dynamic, name2}},
                 config_validator:check_config(InvalidTopology)).

producers_is_not_allowed_as_consumers_test() ->
    ProducerAsConsumer = [{topology,
                           [consumer_cb(name1, 1, [{name2, all}]),
                            producer_db(name2, 1)]}],
    ?assertEqual({error, {producer_as_consumer, name2}},
                 config_validator:check_config(ProducerAsConsumer)).

valid_worker_config_test() ->
    ValidWorkerConfig1 = [{worker_config, [{foo, []}]}],
    ValidWorkerConfig2 = [{worker_config, [{foo, [foo]}, {bar, [baz]}]}],
    ?assertEqual(ok, config_validator:check_config(ValidWorkerConfig1)),
    ?assertEqual(ok, config_validator:check_config(ValidWorkerConfig2)).

worker_config_is_not_a_list_test() ->
    InvalidWorkerConfig = [{worker_config, foo}],
    ?assertEqual({error, {worker_config_is_not_a_list, foo}},
                 config_validator:check_config(InvalidWorkerConfig)).

invalid_worker_config_test() ->
    InvalidWorkerConfig1 = [{worker_config, [{foo}]}],
    InvalidWorkerConfig2 = [{worker_config, [{1, foo}]}],
    InvalidWorkerConfig3 = [{worker_config, [{foo, bar, baz}]}],
    ?assertEqual({error, {invalid_worker_config, {foo}}},
                 config_validator:check_config(InvalidWorkerConfig1)),
    ?assertEqual({error, {invalid_worker_config, {1, foo}}},
                 config_validator:check_config(InvalidWorkerConfig2)),
    ?assertEqual({error, {invalid_worker_config, {foo, bar, baz}}},
                 config_validator:check_config(InvalidWorkerConfig3)).

consumer_cb(Name, NumWorkers) ->
    consumer_cb(Name, NumWorkers, _Targets = []).

consumer_cb(Name, NumWorkers, Targets) ->
    consumer(Name, _Callback = epw_dummy, NumWorkers, Targets).

consumer(Name, Callback, NumWorkers) ->
    consumer(Name, Callback, NumWorkers, _Targets = []).

consumer(Name, Callback, NumWorkers, Targets) ->
    worker(Name, _WorkerType = consumer, Callback, NumWorkers, Targets).

producer_db(Name, NumWorkers) ->
    producer_db(Name, NumWorkers, _Targets = []).

producer_db(Name, NumWorkers, Targets) ->
    producer(Name, _Callback = eg_dummy, NumWorkers, Targets).

producer(Name, Callback, NumWorkers, Targets) ->
    worker(Name, _WorkerType = producer, Callback, NumWorkers, Targets).

worker(Name, WorkerType, Callback, NumWorkers, Targets) ->
    {Name, WorkerType, Callback, NumWorkers, Targets}.
