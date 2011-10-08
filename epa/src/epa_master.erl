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
%% @type worker_type() = WorkerType:: epw.
%%
%% @type distribution_type() = DistributionType:: all | random | keyhash.
%%
%% @type target() = {Name::atom(), distribution_type()}.
%%
%% @type worker() = {Name::atom(), worker_type(), Callback::atom(),
%%                   NumberOfWorkers::integer(), [target()]}.
%%
%%-------------------------------------------------------------------

-module(epa_master).

-behaviour(gen_server).

%% API
-export([start_link/1]).
-export([stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Config) when is_list(Config) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Config], []).

stop() ->
    gen_server:call(?SERVER, stop).

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
    Topology = proplists:get_value(topology, Config, []),
    i_start_topology(Topology),
    {ok, #state{}}.

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
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

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
i_start_topology(Topology) ->
    {ok, EpcList} = i_start_all_epc(Topology),
    i_connect_epcs(Topology, EpcList),
    ok.

i_start_all_epc(Topology) ->
    EpcList = i_start_all_epc(Topology, _EpcList = []),
    {ok, EpcList}.

i_start_all_epc([{Name, epw, WorkerCallback, _Children, _Targets} | Rest], Acc) ->
    {ok, WorkerSup} = epw_sup_master:start_worker_sup(WorkerCallback),
    {ok, Epc} = epc_sup:start_epc(WorkerSup),
    i_start_all_epc(Rest, [{Name, Epc} | Acc]);
i_start_all_epc([], Acc) ->
    Acc.

i_connect_epcs([{Name, epw, _Cb, _Children, Targets} | Rest], EpcList) ->
    Pid = proplists:get_value(Name, EpcList),
    i_connect_epcs_to_targets(Pid, Targets, EpcList),
    i_connect_epcs(Rest, EpcList);
i_connect_epcs([], _EpcList) ->
    ok.

i_connect_epcs_to_targets(_Pid, _NamedTargets = [], _EpcList) ->
    ok;
i_connect_epcs_to_targets(Pid, NamedTargets, EpcList) ->
    Targets = lists:map(
                   fun({Name, Type}) ->
                           Pid = proplists:get_value(Name, EpcList),
                           {Pid, Type}
                   end, NamedTargets),
    epc:set_targets(Pid, Targets).

