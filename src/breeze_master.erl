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

%%-------------------------------------------------------------------
%% @author David Haglund
%% @copyright 2011, David Haglund
%% @doc
%%
%% @end
%%
%% @type worker_type() = producer | consumer
%%
%% @type distribution_type() = DistributionType:: all | random | keyhash.
%%
%% @type target() = {Name::atom(), distribution_type()}.
%%
%% @type worker() = {Name::atom(), worker_type(), Callback::atom(),
%%                   NumberOfWorkers::integer(), [target()]}.
%%
%%-------------------------------------------------------------------

-module(breeze_master).

-behaviour(gen_server).

%% API
-export([start_link/1]).
-export([stop/0]).

-export([set_and_start_configuration/1]).

-export([get_controller/1]).

-export([get_worker_mode_by_type/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {controller_list = []}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link(Config::list()) -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Config) when is_list(Config) ->
    case breeze_config_validator:check_config(Config) of
        ok ->
            gen_server:start_link({local, ?SERVER}, ?MODULE, [Config], []);
        Error ->
            Error
    end.

stop() ->
    gen_server:call(?SERVER, stop).

set_and_start_configuration(Config) when is_list(Config) ->
    case breeze_config_validator:check_config(Config) of
        ok ->
	    gen_server:call(?SERVER, {set_and_start_config, Config});
        Error ->
            Error
    end.

get_controller(Name) when is_atom(Name) ->
    gen_server:call(?SERVER, {get_controller, Name}).

% TODO: find a better module for these functions
get_worker_mode_by_type(producer) ->
    breeze_generating_worker;
get_worker_mode_by_type(consumer) ->
    breeze_processing_worker.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Config]) ->
    ControllerList = i_start(Config),
    {ok, #state{controller_list = ControllerList}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({get_controller, Name}, _From, State) ->
    Result = i_get_controller(Name, State#state.controller_list),
    {reply, Result, State};
handle_call({set_and_start_config, Config}, _From,
	    State = #state{controller_list = []}) ->
    ControllerList = i_start(Config),
    {reply, ok, State#state{controller_list = ControllerList}};
handle_call({set_and_start_config, _Config}, _From, State) ->
    {reply, {error, already_have_a_configuration}, State};
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(Request, _From, State) ->
    {reply, {error, {invalid_request, Request}}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
i_start(Config) ->
    Topology = proplists:get_value(topology, Config, []),
    WorkerConfigs = proplists:get_value(worker_config, Config, []),
    i_start_topology(Topology, WorkerConfigs).

i_start_topology(Topology, WorkerConfigs) ->
    {ok, ControllerList} = i_start_all_worker_controllers(Topology),
    i_connect_worker_controllers_by_type(consumer, Topology, ControllerList),
    i_start_workers_by_type(consumer, Topology, ControllerList, WorkerConfigs),

    i_connect_worker_controllers_by_type(producer, Topology, ControllerList),
    i_start_workers_by_type(producer, Topology, ControllerList, WorkerConfigs),
    ControllerList.

% i_start_all_worker_controller/1
i_start_all_worker_controllers(Topology) ->
    {ok, Consumers} = i_start_all_worker_controllers_by_type(consumer, Topology),
    {ok, Producer} = i_start_all_worker_controllers_by_type(producer, Topology),
    {ok, Consumers ++ Producer}.

% i_start_all_consumer_worker_controller/1
i_start_all_worker_controllers_by_type(WorkerType, Topology) ->
    i_start_all_worker_controllers_by_type(WorkerType, Topology,
					  _ControllerList = []).

i_start_all_worker_controllers_by_type(WorkerType,
			[{Name, WorkerType, WorkerCallback, _C, _T} | Rest],
			Acc) ->
    {ok, Controller} = i_start_worker_controller(Name, WorkerType,
						 WorkerCallback),
    i_start_all_worker_controllers_by_type(WorkerType, Rest,
					   [{Name, Controller} | Acc]);
i_start_all_worker_controllers_by_type(WorkerType, [_| Rest], Acc) ->
    i_start_all_worker_controllers_by_type(WorkerType, Rest, Acc);
i_start_all_worker_controllers_by_type(_WorkerType, [], Acc) ->
    {ok, lists:reverse(Acc)}.

i_start_worker_controller(Name, WorkerType, WorkerCallback) ->
    WorkerMod = get_worker_mode_by_type(WorkerType),
    {ok, WorkerSup} = breeze_worker_supersup:start_worker_sup(
			WorkerMod, WorkerCallback),
    breeze_worker_controller_sup:start_worker_controller(Name, WorkerMod,
							 WorkerSup).

% i_connect_worker_controllers_by_type/3
i_connect_worker_controllers_by_type(WorkerType,
		       [{Name, WorkerType, _Cb, _C, Targets} | Rest],
		       ControllerList) ->
    Pid = proplists:get_value(Name, ControllerList),
    i_connect_worker_controllers_to_targets(Pid, Targets, ControllerList),
    i_connect_worker_controllers_by_type(WorkerType, Rest, ControllerList);
i_connect_worker_controllers_by_type(WorkerType, [_ | Rest], ControllerList) ->
    i_connect_worker_controllers_by_type(WorkerType, Rest, ControllerList);
i_connect_worker_controllers_by_type(_WorkerType, [], _ControllerList) ->
    ok.

i_connect_worker_controllers_to_targets(_Pid, _NamedTargets = [],
					_ControllerList) ->
    ok;
i_connect_worker_controllers_to_targets(Pid, NamedTargets, ControllerList) ->
    Targets = lists:map(
                   fun({Name, Type}) ->
                           NamePid = proplists:get_value(Name, ControllerList),
                           {NamePid, Type}
                   end, NamedTargets),
    breeze_worker_controller:set_targets(Pid, Targets).

% i_start_workers_by_type/3
i_start_workers_by_type(WorkerType, [{Name, WorkerType, _Cb, dynamic, _T} |
				     Rest], ControllerList, WorkerConfigs) ->
    Pid = proplists:get_value(Name, ControllerList),
    breeze_worker_controller:enable_dynamic_workers(Pid),
    i_start_workers_by_type(WorkerType, Rest, ControllerList, WorkerConfigs);
i_start_workers_by_type(WorkerType,
			[{Name, WorkerType, _Cb, NumberOfWorkers, _Targets} |
			 Rest], ControllerList, WorkerConfigs) ->
    Pid = proplists:get_value(Name, ControllerList),
    WorkerConfig = proplists:get_value(Name, WorkerConfigs, []),
    breeze_worker_controller:start_workers(Pid, NumberOfWorkers, WorkerConfig),
    i_start_workers_by_type(WorkerType, Rest, ControllerList, WorkerConfigs);
i_start_workers_by_type(WorkerType, [_| Rest], ControllerList, WorkerConfigs) ->
    i_start_workers_by_type(WorkerType, Rest, ControllerList, WorkerConfigs);
i_start_workers_by_type(_WorkerType, [], _ControllerList, _WorkerConfigs) ->
    ok.

% i_get_controller/2
i_get_controller(Name, ControllerList) ->
    case proplists:lookup(Name, ControllerList) of
	{Name, Pid} ->
	    {ok, Pid};
	_ ->
	    {error, {not_found, Name}}
    end.
