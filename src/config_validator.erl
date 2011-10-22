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

-module(config_validator).

%% API
-export([check_config/1]).



%%%===================================================================
%%% API
%%%===================================================================
check_config(Config) ->
    CheckFuns =
        [{topology,
          [fun i_check_topology_syntax/1,
           fun i_check_topology_duplicated_names/1,
           fun i_check_topology_target_references/1,
           fun i_check_topology_target_reference_types/1,
           fun i_check_dynamic_target_must_have_dynamic_workers/1,
           fun i_check_keyhash_target_must_not_be_dynamic/1,
           fun i_check_topology_worker_types/1,
           fun i_check_worker_callback_module/1,
           fun i_check_producer_as_consumer/1
          ]},
         {worker_config,
          [fun i_check_worker_config_syntax/1,
           fun i_check_worker_configs_is_two_tuples_with_atom_and_term/1]}],

    i_check_all(Config, CheckFuns).

%%%===================================================================
%%% Internal functions
%%%===================================================================
i_check_all(Config, [{Key, CheckFuns} | Rest]) ->
    KeyConfig = proplists:get_value(Key, Config, []),
    case i_check_all_funs(KeyConfig, CheckFuns) of
        ok ->
            i_check_all(Config, Rest);
        Error ->
            Error
    end;
i_check_all(_Config, []) ->
    ok.

i_check_all_funs(KeyConfig, [CheckFun | CheckFuns]) ->
    case CheckFun(KeyConfig) of
        ok ->
            i_check_all_funs(KeyConfig, CheckFuns);
        Error ->
            Error
    end;
i_check_all_funs(_KeyConfig, []) ->
    ok.

% i_check_topology_syntax/1
i_check_topology_syntax([Worker|Rest]) when is_tuple(Worker) ->
    case i_check_worker_tuple(Worker) of
        ok ->
            i_check_topology_syntax(Rest);
        Error ->
            Error
    end;
i_check_topology_syntax([InvalidWorker|_Rest]) ->
    {error, {invalid_topology_syntax, InvalidWorker}};
i_check_topology_syntax([]) ->
    ok.

i_check_worker_tuple({Name, Type, WorkerCallback, NumWorkers, Targets}) when
  is_atom(Name) andalso
      is_atom(Type) andalso
      is_atom(WorkerCallback) andalso
      (is_integer(NumWorkers) orelse NumWorkers =:= dynamic) andalso
      is_list(Targets) ->
    i_check_targets(Targets);
i_check_worker_tuple(Tuple) ->
    {error, {invalid_topology_syntax, Tuple}}.

i_check_targets([{Name, Type}|Rest]) when is_atom(Name) andalso is_atom(Type) ->
    i_check_targets(Rest);
i_check_targets([InvalidTarget|_Rest]) ->
    {error, {invalid_topology_target_syntax, InvalidTarget}};
i_check_targets([]) ->
    ok.

% i_check_topology_duplicated_names/1
i_check_topology_duplicated_names(Topology) ->
    i_check_topology_duplicated_names(Topology, _ValidNames = []).

i_check_topology_duplicated_names([{Name, _, _, _, _} | Rest], ValidNames) ->
    case lists:member(Name, ValidNames) of
        true ->
            {error, duplicated_worker_name};
        _ ->
            i_check_topology_duplicated_names(Rest, [Name | ValidNames])
    end;
i_check_topology_duplicated_names([], _ValidNames) ->
    ok.

% i_check_topology_target_references/1
i_check_topology_target_references(Topology) ->
    ValidNames = i_get_all_names(Topology),
    ErrorType = invalid_target_ref,
    i_check_all_targets_are_in_target_set(Topology, ValidNames, '_', ErrorType).

i_get_all_names(Topology) ->
    lists:map(fun({Name,_,_,_,_}) -> Name end, Topology).

% i_check_topology_target_reference_types/1
i_check_topology_target_reference_types([{_, _, _, _, Targets} | Rest]) ->
    case i_check_target_types(Targets) of
        ok ->
            i_check_topology_target_reference_types(Rest);
        Error ->
            Error
    end;
i_check_topology_target_reference_types([]) ->
    ok.

i_check_target_types([{_, all} |Rest]) ->
    i_check_target_types(Rest);
i_check_target_types([{_, random} | Rest]) ->
    i_check_target_types(Rest);
i_check_target_types([{_, keyhash} | Rest]) ->
    i_check_target_types(Rest);
i_check_target_types([{_, dynamic} | Rest]) ->
    i_check_target_types(Rest);
i_check_target_types([{_, InvalidType} | _Rest]) ->
    {error, {invalid_target_ref_type, InvalidType}};
i_check_target_types([]) ->
    ok.

% i_check_dynamic_target_must_have_dynamic_workers/1
i_check_dynamic_target_must_have_dynamic_workers(Topology) ->
    DynamicTargets = i_find_dynamic_worker_names(Topology),
    ErrorType = dynamic_target_must_have_dynamic_workers,
    TargetKey = dynamic,
    i_check_all_targets_are_in_target_set(Topology, DynamicTargets,
                                          TargetKey, ErrorType).

i_find_dynamic_worker_names(Topology) ->
    lists:foldl(
      fun ({Name, _, _, dynamic, _}, Acc) -> [Name|Acc];
         (_, Acc) -> Acc
      end,
      [], Topology).

% i_check_keyhash_target_must_not_be_dynamic/1
i_check_keyhash_target_must_not_be_dynamic(Topology) ->
    NonDynamicTargets = i_find_non_dynamic_worker_names(Topology),
    ErrorType = keyhash_targets_must_not_be_dynamic,
    TargetKey = keyhash,
    i_check_all_targets_are_in_target_set(Topology, NonDynamicTargets,
                                          TargetKey, ErrorType).

i_find_non_dynamic_worker_names(Topology) ->
    lists:foldl(
      fun ({_,_,_, dynamic, _}, Acc) -> Acc;
         ({Name, _,_,_,_}, Acc) -> [Name|Acc]
      end,
      [], Topology).

% i_check_topology_worker_types/1
i_check_topology_worker_types([{_, producer, _, _, _} | Rest]) ->
    i_check_topology_worker_types(Rest);
i_check_topology_worker_types([{_, consumer, _, _, _} | Rest]) ->
    i_check_topology_worker_types(Rest);
i_check_topology_worker_types([{_, InvalidWorkerType, _, _, _} | _Rest]) ->
    {error, {invalid_worker_type, InvalidWorkerType}};
i_check_topology_worker_types([]) ->
    ok.

% i_check_worker_callback_module/1
i_check_worker_callback_module([{_, WorkerType, WorkerCallback,_,_} | Rest]) ->
    WorkerMod = breeze_master:get_worker_mode_by_type(WorkerType),
    case WorkerMod:validate_module(WorkerCallback) of
        true ->
            i_check_worker_callback_module(Rest);
        _E ->
            {error, {invalid_worker_callback_module, WorkerCallback}}
    end;
i_check_worker_callback_module([]) ->
    ok.

% i_check_producer_as_consumer/1
i_check_producer_as_consumer(Topology) ->
    ConsumerNames = i_find_consumer_names(Topology),
    ErrorType = producer_as_consumer,
    i_check_all_targets_are_in_target_set(Topology, ConsumerNames, '_',
                                          ErrorType).

i_find_consumer_names(Topology) ->
    lists:foldl(
      fun({Name, consumer, _, _, _}, Acc) -> [Name | Acc];
         (_, Acc) -> Acc
      end, [], Topology).

% i_check_worker_config_syntax/1
i_check_worker_config_syntax(WorkerConfig) when is_list(WorkerConfig) ->
    ok;
i_check_worker_config_syntax(WorkerConfig) ->
    {error, {worker_config_is_not_a_list, WorkerConfig}}.

% i_check_worker_configs_is_two_tuples_with_atom_and_term/1
i_check_worker_configs_is_two_tuples_with_atom_and_term([{Name, _Term} | Rest])
  when is_atom(Name) ->
    i_check_worker_configs_is_two_tuples_with_atom_and_term(Rest);
i_check_worker_configs_is_two_tuples_with_atom_and_term([WorkerConfig | _]) ->
    {error, {invalid_worker_config, WorkerConfig}};
i_check_worker_configs_is_two_tuples_with_atom_and_term([]) ->
    ok.

%% i_check_all_targets_are_in_target_set/4
i_check_all_targets_are_in_target_set([{Name,_,_,_,Targets}|Rest], TargetsSet,
                                      TargetKey, ErrorType) ->
    case i_check_target_name_is_member_list(
           Targets, TargetKey, TargetsSet -- [Name], ErrorType) of
        ok ->
            i_check_all_targets_are_in_target_set(
              Rest, TargetsSet, TargetKey, ErrorType);
        Error ->
            Error
    end;
i_check_all_targets_are_in_target_set([], _TSet, _TKey, _ErrorT) ->
    ok.

i_check_target_name_is_member_list([{Name, Type}|Rest],
                                    TargetType, Members, Error)
  when  Type =:= TargetType orelse TargetType =:= '_' ->
    case lists:member(Name, Members) of
        true ->
           i_check_target_name_is_member_list(Rest, TargetType, Members, Error);
        false ->
            {error, {Error, Name}}
    end;
i_check_target_name_is_member_list([_|Rest], TargetType, Members, Error) ->
    i_check_target_name_is_member_list(Rest, TargetType, Members, Error);
i_check_target_name_is_member_list([], _TargetType, _Members, _Error) ->
    ok.
