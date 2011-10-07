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
%% Event processing controller, manages the workers and passed data
%% to them.
%% @end

-module(epc).

-behaviour(gen_server).

%% API
-export([start_link/1]).
-export([set_targets/2]).
-export([start_workers/2]).

-export([sync/1]).

-export([multicast/2]).
-export([randomcast/2]).
-export([keyhashcast/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {sup_pid, workers, targets}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link(Name, SupervisorPid) -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(SupervisorPid) ->
    gen_server:start_link(?MODULE, [SupervisorPid], []).

set_targets(Server, Targets) when is_list(Targets) ->
    gen_server:call(Server, {set_targets, Targets}).

start_workers(Server, NumberOfWorkers) ->
    gen_server:call(Server, {start_workers, NumberOfWorkers}).

multicast(Server,  Msg) ->
    gen_server:cast(Server, {msg, all, Msg}).

randomcast(Server, Msg) ->
    gen_server:cast(Server, {msg, random, Msg}).

keyhashcast(Server, Msg) when is_tuple(Msg) ->
    gen_server:cast(Server, {msg, keyhash, Msg});
keyhashcast(_Server, Msg) ->
    {error, {not_a_valid_message, Msg}}.

sync(Server) ->
    gen_server:call(Server, sync).

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
init([SupervisorPid]) ->
    self() ! {get_worker_sup, SupervisorPid},
    {_, A, B} = now(),
    random:seed(A, B, erlang:phash2(make_ref())),
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
handle_call({start_workers, NumberOfWorkers}, _From,
            State = #state{workers = undefined}) ->
    Options = i_make_options(State),
    Workers = i_start_workers(State#state.sup_pid, NumberOfWorkers, Options),
    {reply, ok, State#state{workers = Workers}};
handle_call({start_workers, _NumberOfWorkers}, _From, State) ->
    {reply, {error, already_started}, State};
handle_call({set_targets, Targets}, _From, State) ->
    {reply, ok, State#state{targets = Targets}};
handle_call(sync, _From, State) ->
    i_sync(State#state.workers),
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

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
handle_cast({msg, all, Msg}, State) ->
    i_multicast(State#state.workers, Msg),
    {noreply, State};
handle_cast({msg, random, Msg}, State) ->
    i_randomcast(State#state.workers, Msg),
    {noreply, State};
handle_cast({msg, keyhash, Msg}, State) ->
    i_keyhashcast(State#state.workers, Msg),
    {noreply, State};
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
handle_info({get_worker_sup, SupervisorPid}, State) ->
    {ok, WorkerSupPid} = epc_sup:get_worker_sup_pid(SupervisorPid),
    {noreply, State#state{sup_pid = WorkerSupPid}};
handle_info({'DOWN', _Ref, process, Pid, _Info}, State0) ->
    State1 = i_restart_worker(Pid, State0),
    {noreply, State1};
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
i_sync(Workers) ->
    lists:foreach(fun({Pid,_}) -> ok = epw:sync(Pid) end, Workers).

i_multicast(Workers, Msg) ->
    lists:foreach(fun({Pid,_}) -> epw:process(Pid, Msg) end, Workers).

i_randomcast(Workers, Msg) ->
    RandInt = random:uniform(length(Workers)),
    {WorkerPid, _} = lists:nth(RandInt, Workers),
    epw:process(WorkerPid, Msg).

i_keyhashcast(Workers, Msg) ->
    Key = element(1, Msg),
    Hash = erlang:phash2(Key, length(Workers)) + 1,
    {WorkerPid, _} = lists:nth(Hash, Workers),
    epw:process(WorkerPid, Msg).

i_make_options(#state{targets = undefined}) ->
    [];
i_make_options(#state{targets = Targets}) ->
    [{targets, Targets}].

i_start_workers(SupPid, NumberOfWorkers, Options) ->
    {ok, Workers} = epw_sup:start_workers(SupPid, NumberOfWorkers, Options),
    i_monitor_workers(Workers).

i_monitor_workers(Workers) ->
    lists:map(fun(Pid) -> Ref = monitor(process, Pid), {Pid, Ref} end, Workers).

i_restart_worker(OldPid, State) ->
    Options = i_make_options(State),
    [NewWorker] = i_start_workers(State#state.sup_pid, 1, Options),
    Workers = lists:keyreplace(OldPid, 1, State#state.workers, NewWorker),
    State#state{workers = Workers}.
