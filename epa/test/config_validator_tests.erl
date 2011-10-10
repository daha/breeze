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
    Topology1 = [{topology, [{name, consumer, epw_dummy, 1, []}]}],
    Topology2 = [{topology, [{name, producer, eg_dummy, 2, []}]}],
    Topology3 = [{topology, [{name1, consumer, epw_dummy, 3,
                              [{name2, all}]},
                             {name2, consumer, epw_dummy, 4, []}]}],
    Topology4 = [{topology, [{name1, consumer, epw_dummy, 5,
                              [{name2, random}]},
                             {name2, consumer, epw_dummy, 6, []}]}],
    Topology5 = [{topology, [{name1, consumer, epw_dummy, 7,
                              [{name2, keyhash}]},
                             {name2, consumer, epw_dummy, 8, []}]}],
    Topology6 = [{topology, [{name1, consumer, epw_dummy, 9,
                              [{name2, keyhash}, {name3, all}]},
                             {name2, consumer, epw_dummy, 10, []},
                             {name3, consumer, epw_dummy, 11, []}]}],
    Topology7 = [{topology, [{name1, producer, eg_dummy, 12,
                              [{name2, random}]},
                             {name2, consumer, epw_dummy, 13, []}]}],
    ?assertEqual(ok, config_validator:check_config(Topology1)),
    ?assertEqual(ok, config_validator:check_config(Topology2)),
    ?assertEqual(ok, config_validator:check_config(Topology3)),
    ?assertEqual(ok, config_validator:check_config(Topology4)),
    ?assertEqual(ok, config_validator:check_config(Topology5)),
    ?assertEqual(ok, config_validator:check_config(Topology6)),
    ?assertEqual(ok, config_validator:check_config(Topology7)),
    ok.

invalid_topology_syntax_check_test() ->
    InvalidTopology1 = [{topology, [foo]}],
    InvalidTopology2 = [{topology, [{foo, consumer, bar, 1}]}],
    InvalidTopology3 = [{topology, [{foo, consumer, bar, 1, [], []}]}],
    InvalidTopology4 = [{topology, [{1, consumer, bar, 1, foo}]}],
    InvalidTopology5 = [{topology, [{foo, 2, bar, 1, foo}]}],
    InvalidTopology6 = [{topology, [{foo, consumer, 3, 1, foo}]}],
    InvalidTopology7 = [{topology, [{foo, consumer, bar, baz, []}]}],

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
                          {foo, consumer, bar, baz, []}}},
                 config_validator:check_config(InvalidTopology7)).

invalid_topology_target_syntax_check_test() ->
    InvalidTopology1 = [{topology, [{foo, consumer, bar, 1, foo}]}],
    InvalidTopology2 = [{topology, [{foo, consumer, bar, 1, [foo]}]}],
    InvalidTopology3 = [{topology, [{foo, consumer, bar, 1, [{foo}]}]}],
    InvalidTopology4 = [{topology, [{foo, consumer, bar, 1,
                                     [{foo, bar, baz}]}]}],
    InvalidTopology5 = [{topology, [{foo, consumer, bar, 1, [{4, bar}]}]}],
    InvalidTopology6 = [{topology, [{foo, consumer, bar, 1, [{foo, 5}]}]}],

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
    InvalidTargetRef1 = [{topology, [{name, consumer, bar, 1, [{name, all}]}]}],
    InvalidTargetRef2 = [{topology, [{name, consumer, bar, 1,
                                      [{invalid_name, all}]}]}],
    InvalidTargetRef3 = [{topology, [{name1, consumer, bar, 1, []},
                                     {name2, consumer, bar, 1,
                                      [{name1, all},
                                       {invalid_name, all}]}]}],
    ?assertEqual({error, {invalid_target_ref, name}},
                 config_validator:check_config(InvalidTargetRef1)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 config_validator:check_config(InvalidTargetRef2)),
    ?assertEqual({error, {invalid_target_ref, invalid_name}},
                 config_validator:check_config(InvalidTargetRef3)),
    ok.

invalid_topology_target_ref_type_test() ->
    InvalidTargetRefType = [{topology, [{name1, consumer, bar, 1, []},
                                         {name2, consumer, bar, 1,
                                          [{name1, foo}]}]}],
    ?assertEqual({error, {invalid_target_ref_type, foo}},
                 config_validator:check_config(InvalidTargetRefType)).

valid_topology_target_ref_type_test() ->
    ValidTargetRefType1 = [{topology, [{name1, consumer, epw_dummy, 1, []},
                                      {name2, consumer, epw_dummy, 1,
                                       [{name1, all}]}]}],
    ValidTargetRefType2 = [{topology, [{name1, consumer, epw_dummy, 1, []},
                                      {name2, consumer, epw_dummy, 1,
                                       [{name1, random}]}]}],
    ValidTargetRefType3 = [{topology, [{name1, consumer, epw_dummy, 1, []},
                                      {name2, consumer, epw_dummy, 1,
                                       [{name1, keyhash}]}]}],
    ValidTargetRefType4 = [{topology, [{name1, producer, eg_dummy, 1,
                                        [{name2, keyhash}]},
                                      {name2, consumer, epw_dummy, 1, []}]}],
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType1)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType2)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType3)),
    ?assertEqual(ok, config_validator:check_config(ValidTargetRefType4)),
    ok.

invalid_topology_duplicated_worker_name_test() ->
    DupName = [{topology, [{name, consumer, bar, 1, []},
                           {name, consumer, bar, 1, []}]}],
    ?assertEqual({error, duplicated_worker_name},
                 config_validator:check_config(DupName)).

invalid_topology_worker_type_test() ->
    InvalidWorkerType = [{topology, [{name, foo, bar, 1, []}]}],
    ?assertEqual({error, {invalid_worker_type, foo}},
                 config_validator:check_config(InvalidWorkerType)).

invalid_topology_worker_callback_module_test() ->
    InvalidWorkerCallbackModule = [{topology,
                                    [{name, consumer, invalid_callback, 1,
                                      []}]}],
    ?assertEqual({error, {invalid_worker_callback_module, invalid_callback}},
                 config_validator:check_config(InvalidWorkerCallbackModule)).

producers_is_not_allowed_as_consumers_test() ->
    ProducerAsConsumer = [{topology,
                           [{name1, consumer, epw_dummy, 1, [{name2, all}]},
                            {name2, producer, eg_dummy, 1, []}]}],
    ?assertEqual({error, {producer_as_consumer, name2}},
                 config_validator:check_config(ProducerAsConsumer)).
