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
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
check_config(Config) ->
    CheckFuns =
        [{topology,
          [fun i_check_topology_syntax/1,
           fun i_check_topology_duplicated_names/1,
           fun i_check_topology_target_references/1,
           fun i_check_topology_target_reference_types/1,
           fun i_check_dynamic_target_must_have_dynamic_workers/1,
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
    i_check_topology_target_references(Topology, []).

i_check_topology_target_references([{Name, _, _, _, Targets} | Rest],
                                   ConsumedNames) ->
    ValidNames = ConsumedNames ++ i_extract_names(Rest),
    case i_check_target_names_is_valid(Targets, ValidNames) of
        ok ->
            i_check_topology_target_references(Rest, [Name | ConsumedNames]);
        Error ->
            Error
    end;
i_check_topology_target_references([], _) ->
    ok.

i_check_target_names_is_valid([], _ValidNames) ->
    ok;
i_check_target_names_is_valid([{TargetName, _} | Rest], ValidNames) ->
    case lists:member(TargetName, ValidNames) of
        true ->
            i_check_target_names_is_valid(Rest, ValidNames);
        _ ->
            {error, {invalid_target_ref, TargetName}}
    end.

i_extract_names(List) ->
    lists:map(fun(Worker) -> element(1, Worker) end, List).

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
    DynamicTargets = lists:foldl(
                       fun ({Name, _, _, dynamic, _}, Acc) -> [Name|Acc];
                           (_, Acc) -> Acc
                       end,
                       [], Topology),
    i_check_dynamic_target_must_have_dynamic_workers(Topology, DynamicTargets).

i_check_dynamic_target_must_have_dynamic_workers([{_,_,_,_,Targets} | Rest],
                                                 DynamicTargets) ->
    case i_check_dynamic_targets_are_dynamic(Targets, DynamicTargets) of
        ok ->
            i_check_dynamic_target_must_have_dynamic_workers(
              Rest, DynamicTargets);
        Error ->
            Error
    end;
i_check_dynamic_target_must_have_dynamic_workers([], _DynamicTargets) ->
    ok.

i_check_dynamic_targets_are_dynamic([{Name, dynamic} | Rest], DynamicTargets) ->
    case lists:member(Name, DynamicTargets) of
        true ->
            i_check_dynamic_targets_are_dynamic(Rest, DynamicTargets);
        false ->
            {error, {dynamic_target_must_have_dynamic_workers, Name}}
    end;
i_check_dynamic_targets_are_dynamic([_Target|Rest], DynamicTargets) ->
    i_check_dynamic_targets_are_dynamic(Rest, DynamicTargets);
i_check_dynamic_targets_are_dynamic([], _DynamicTargets) ->
    ok.

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
    WorkerMod = epa_master:get_worker_mode_by_type(WorkerType),
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
    ProducerNames = lists:foldl(
                      fun({Name, producer, _, _, _}, Acc) -> [Name | Acc];
                         (_, Acc) -> Acc
                      end, [], Topology),
    i_check_producer_as_consumer(Topology, ProducerNames).

i_check_producer_as_consumer([{_, _, _, _, Targets} | Rest], ProducerNames) ->
    case i_check_producer_as_consumer_target(Targets, ProducerNames) of
        ok ->
            i_check_producer_as_consumer(Rest, ProducerNames);
        Error ->
            Error
    end;
i_check_producer_as_consumer([], _ProducerNames) ->
    ok.

i_check_producer_as_consumer_target([{Name, _} | Rest], ProducerNames) ->
    case lists:member(Name, ProducerNames) of
        false ->
            i_check_producer_as_consumer_target(Rest, ProducerNames);
        _ ->
            {error, {producer_as_consumer, Name}}
    end;
i_check_producer_as_consumer_target([], _ProducerNames) ->
    ok.

% i_check_worker_config_syntax/
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
