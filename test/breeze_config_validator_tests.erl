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

-module(breeze_config_validator_tests).

-include_lib("eunit/include/eunit.hrl").

valid_topology_test() ->
    Topology1 = [{topology, [processing_worker_cb(name, 1)]}],
    Topology2 = [{topology, [generating_worker_cb(name, 2)]}],
    Topology3 = [{topology, [processing_worker_cb(name1, 3, [{name2, all}]),
                             processing_worker_cb(name2, 4)]}],
    Topology4 = [{topology, [processing_worker_cb(name1, 5, [{name2, random}]),
                             processing_worker_cb(name2, 6)]}],
    Topology5 = [{topology, [processing_worker_cb(name1, 7, [{name2, keyhash}]),
                             processing_worker_cb(name2, 8)]}],
    Topology6 = [{topology, [processing_worker_cb(name1, 9,
                                      [{name2, keyhash}, {name3, all}]),
                             processing_worker_cb(name2, 10),
                             processing_worker_cb(name3, 11)]}],
    Topology7 = [{topology, [generating_worker_cb(name1, 12, [{name2, random}]),
                             processing_worker_cb(name2, 13)]}],
    Topology8 = [{topology, [generating_worker_cb(name1, 14,
						  [{name2, dynamic}]),
                             processing_worker_cb(name2, dynamic)]}],
    ?assertEqual(ok, breeze_config_validator:check_config(Topology1)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology2)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology3)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology4)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology5)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology6)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology7)),
    ?assertEqual(ok, breeze_config_validator:check_config(Topology8)),
    ok.

invalid_topology_syntax_check_test() ->
    InvalidTopology1 = [{topology, [foo]}],
    InvalidTopology2 = [{topology, [{foo, processing_worker, bar, 1}]}],
    InvalidTopology3 = [{topology, [{foo, processing_worker, bar, 1, [], []}]}],
    InvalidTopology4 = [{topology, [processing_worker(1, bar, 1, foo)]}],
    InvalidTopology5 = [{topology, [worker(foo, 2, bar, 1, foo)]}],
    InvalidTopology6 = [{topology, [processing_worker(foo, 3, 1, foo)]}],
    InvalidTopology7 = [{topology, [processing_worker(foo, bar, baz)]}],

    ?assertEqual({error, {invalid_topology_syntax, foo}},
                 breeze_config_validator:check_config(InvalidTopology1)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, processing_worker, bar, 1}}},
                 breeze_config_validator:check_config(InvalidTopology2)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, processing_worker, bar, 1, [], []}}},
                 breeze_config_validator:check_config(InvalidTopology3)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {1, processing_worker, bar, 1, foo}}},
                 breeze_config_validator:check_config(InvalidTopology4)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, 2, bar, 1, foo}}},
                 breeze_config_validator:check_config(InvalidTopology5)),
    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, processing_worker, 3, 1, foo}}},
                 breeze_config_validator:check_config(InvalidTopology6)),
    ?assertEqual({error, {invalid_topology_syntax,
                          processing_worker(foo, bar, baz)}},
                 breeze_config_validator:check_config(InvalidTopology7)).

invalid_topology_target_syntax_check_test() ->
    InvalidTopology1 = [{topology, [processing_worker(foo, bar, 1, foo)]}],
    InvalidTopology2 = [{topology, [processing_worker(foo, bar, 1, [foo])]}],
    InvalidTopology3 = [{topology, [processing_worker(foo, bar, 1, [{foo}])]}],
    InvalidTopology4 = [{topology, [processing_worker(foo, bar, 1,
						      [{foo, bar, baz}])]}],
    InvalidTopology5 = [{topology, [processing_worker(foo, bar, 1,
						      [{4, bar}])]}],
    InvalidTopology6 = [{topology, [processing_worker(foo, bar, 1,
						      [{foo, 5}])]}],

    ?assertEqual({error, {invalid_topology_syntax,
                          {foo, processing_worker, bar, 1, foo}}},
                 breeze_config_validator:check_config(InvalidTopology1)),
    ?assertEqual({error, {invalid_topology_target_syntax, foo}},
                 breeze_config_validator:check_config(InvalidTopology2)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo}}},
                 breeze_config_validator:check_config(InvalidTopology3)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo, bar, baz}}},
                 breeze_config_validator:check_config(InvalidTopology4)),
    ?assertEqual({error, {invalid_topology_target_syntax, {4, bar}}},
                 breeze_config_validator:check_config(InvalidTopology5)),
    ?assertEqual({error, {invalid_topology_target_syntax, {foo, 5}}},
                 breeze_config_validator:check_config(InvalidTopology6)).

invalid_topology_target_references_test() ->
    InvalidTargetRef1 = [{topology, [processing_worker(name, bar, 1,
						       [{name, all}])]}],
    InvalidTargetRef2 = [{topology, [processing_worker(name, bar, 1,
                                      [{invalid_name, all}])]}],
    InvalidTargetRef3 = [{topology, [processing_worker(name1, bar, 1),
                                     processing_worker(name2, bar, 1,
                                              [{name1, all},
                                               {invalid_name, all}])]}],
    ?assertEqual({error, {invalid_target_ref, name}},
                 breeze_config_validator:check_config(InvalidTargetRef1)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 breeze_config_validator:check_config(InvalidTargetRef2)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 breeze_config_validator:check_config(InvalidTargetRef3)),
    ok.

invalid_topology_target_ref_type_test() ->
    InvalidTargetRefType = [{topology, [processing_worker(name1, bar, 1),
                                        processing_worker(name2, bar, 1,
                                                 [{name1, foo}])]}],
    ?assertEqual({error, {invalid_target_ref_type, foo}},
                 breeze_config_validator:check_config(InvalidTargetRefType)).

valid_topology_target_ref_type_test() ->
    ValidTargetRefType1 =
        [{topology, [processing_worker_cb(name1, 1),
                     processing_worker_cb(name2, 1, [{name1, all}])]}],
    ValidTargetRefType2 =
        [{topology, [processing_worker_cb(name1, 1),
                     processing_worker_cb(name2, 1, [{name1, random}])]}],
    ValidTargetRefType3 =
        [{topology, [processing_worker_cb(name1, 1),
                     processing_worker_cb(name2, 1, [{name1, keyhash}])]}],
    ValidTargetRefType4 =
        [{topology, [generating_worker_cb(name1, 1, [{name2, keyhash}]),
                     processing_worker_cb(name2, 1)]}],
    ?assertEqual(ok, breeze_config_validator:check_config(ValidTargetRefType1)),
    ?assertEqual(ok, breeze_config_validator:check_config(ValidTargetRefType2)),
    ?assertEqual(ok, breeze_config_validator:check_config(ValidTargetRefType3)),
    ?assertEqual(ok, breeze_config_validator:check_config(ValidTargetRefType4)),
    ok.

invalid_topology_duplicated_worker_name_test() ->
    DupName = [{topology, [processing_worker(name, bar, 1),
                           processing_worker(name, bar, 1)]}],
    ?assertEqual({error, duplicated_worker_name},
                 breeze_config_validator:check_config(DupName)).

invalid_topology_worker_type_test() ->
    InvalidWorkerType = [{topology, [worker(name, foo, bar, 1, [])]}],
    ?assertEqual({error, {invalid_worker_type, foo}},
                 breeze_config_validator:check_config(InvalidWorkerType)).

invalid_topology_worker_callback_module_test() ->
    InvalidCallback =
        [{topology, [processing_worker(name, invalid_callback, 1)]}],
    ?assertEqual({error, {invalid_worker_callback_module, invalid_callback}},
                 breeze_config_validator:check_config(InvalidCallback)).

dynamic_target_must_be_dynamic_test() ->
    NotDynamicWorker = [{topology,
                         [processing_worker_cb(name1, 1, [{name2, dynamic}]),
                          processing_worker_cb(name2, 1)]}],
    ?assertEqual({error, {dynamic_target_must_have_dynamic_workers, name2}},
                 breeze_config_validator:check_config(NotDynamicWorker)).

keyhash_targets_must_not_be_dynamic_test() ->
    InvalidTopology = [{topology,
                        [processing_worker_cb(name1, 1, [{name2, keyhash}]),
                         processing_worker_cb(name2, dynamic)]}],
    ?assertEqual({error, {keyhash_targets_must_not_be_dynamic, name2}},
                 breeze_config_validator:check_config(InvalidTopology)).

generating_workers_is_not_allowed_as_processing_workers_test() ->
    ProducerAsConsumer = [{topology,
                           [processing_worker_cb(name1, 1, [{name2, all}]),
                            generating_worker_cb(name2, 1)]}],
    ?assertEqual({error, {generating_worker_as_processing_worker, name2}},
                 breeze_config_validator:check_config(ProducerAsConsumer)).

valid_worker_config_test() ->
    ValidWorkerConfig1 = [{worker_config, [{foo, []}]}],
    ValidWorkerConfig2 = [{worker_config, [{foo, [foo]}, {bar, [baz]}]}],
    ?assertEqual(ok, breeze_config_validator:check_config(ValidWorkerConfig1)),
    ?assertEqual(ok, breeze_config_validator:check_config(ValidWorkerConfig2)).

worker_config_is_not_a_list_test() ->
    InvalidWorkerConfig = [{worker_config, foo}],
    ?assertEqual({error, {worker_config_is_not_a_list, foo}},
                 breeze_config_validator:check_config(InvalidWorkerConfig)).

invalid_worker_config_test() ->
    InvalidWorkerConfig1 = [{worker_config, [{foo}]}],
    InvalidWorkerConfig2 = [{worker_config, [{1, foo}]}],
    InvalidWorkerConfig3 = [{worker_config, [{foo, bar, baz}]}],
    ?assertEqual({error, {invalid_worker_config, {foo}}},
                 breeze_config_validator:check_config(InvalidWorkerConfig1)),
    ?assertEqual({error, {invalid_worker_config, {1, foo}}},
                 breeze_config_validator:check_config(InvalidWorkerConfig2)),
    ?assertEqual({error, {invalid_worker_config, {foo, bar, baz}}},
                 breeze_config_validator:check_config(InvalidWorkerConfig3)).

processing_worker_cb(Name, NumWorkers) ->
    processing_worker_cb(Name, NumWorkers, _Targets = []).

processing_worker_cb(Name, NumWorkers, Targets) ->
    processing_worker(Name, _Callback = pw_dummy, NumWorkers, Targets).

processing_worker(Name, Callback, NumWorkers) ->
    processing_worker(Name, Callback, NumWorkers, _Targets = []).

processing_worker(Name, Callback, NumWorkers, Targets) ->
    WorkerType = processing_worker,
    worker(Name, WorkerType, Callback, NumWorkers, Targets).

generating_worker_cb(Name, NumWorkers) ->
    generating_worker_cb(Name, NumWorkers, _Targets = []).

generating_worker_cb(Name, NumWorkers, Targets) ->
    generating_worker(Name, _Callback = gw_dummy, NumWorkers, Targets).

generating_worker(Name, Callback, NumWorkers, Targets) ->
    WorkerType = generating_worker,
    worker(Name, WorkerType, Callback, NumWorkers, Targets).

worker(Name, WorkerType, Callback, NumWorkers, Targets) ->
    {Name, WorkerType, Callback, NumWorkers, Targets}.
