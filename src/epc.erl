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
-export([start_link/3]).
-export([stop/1]).

-export([set_targets/2]).
-export([start_workers/2]).
-export([start_workers/3]).
-export([enable_dynamic_workers/1]).

-export([sync/1]).

-export([multicast/2]).
-export([random_cast/2]).
-export([keyhash_cast/2]).
-export([dynamic_cast/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {
                worker_mod,
                sup_pid,
                workers = [],
                worker_config = [],
                targets,
                dynamic = false
               }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link(Name, WorkerMod, WorkerSup) -> 
%%           {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Name, WorkerMod, WorkerSup)
  when is_atom(Name), is_atom(WorkerMod), is_pid(WorkerSup) ->
    gen_server:start_link({local, Name}, ?MODULE, [WorkerMod, WorkerSup], []).

stop(Server) ->
    gen_server:call(Server, stop).

set_targets(Server, Targets) when is_list(Targets) ->
    gen_server:call(Server, {set_targets, Targets}).

start_workers(Server, NumberOfWorkers) ->
    start_workers(Server, NumberOfWorkers, _WorkerConfig = []).
start_workers(Server, NumberOfWorkers, WorkerConfig)
  when is_integer(NumberOfWorkers) ->
    gen_server:call(Server, {start_workers, NumberOfWorkers, WorkerConfig}).

enable_dynamic_workers(Server) ->
    gen_server:call(Server, dynamic_workers).

multicast(Server,  Msg) ->
    gen_server:cast(Server, {msg, all, Msg}).

random_cast(Server, Msg) ->
    gen_server:cast(Server, {msg, random, Msg}).

keyhash_cast(Server, Msg) when is_tuple(Msg) andalso size(Msg) > 0 ->
    gen_server:cast(Server, {msg, keyhash, Msg});
keyhash_cast(_Server, Msg) ->
    {error, {not_a_valid_message, Msg}}.

dynamic_cast(Server, Msg) when is_tuple(Msg) andalso size(Msg) > 0 ->
    gen_server:cast(Server, {msg, unique, Msg});
dynamic_cast(_Server, Msg) ->
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
init([WorkerMod, WorkerSup]) ->
    {_, A, B} = now(),
    random:seed(A, B, erlang:phash2(make_ref())),
    {ok, #state{worker_mod = WorkerMod, sup_pid = WorkerSup}}.

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
handle_call({start_workers, NumberOfWorkers, WorkerConfig}, _From,
            State = #state{workers = [], dynamic = false}) ->
    Workers = i_start_workers(State, NumberOfWorkers, WorkerConfig),
    {reply, ok, State#state{workers = Workers, worker_config = WorkerConfig}};
handle_call({start_workers, _NumberOfWorkers, _WorkerConfig}, _From,
            State = #state{dynamic = false}) ->
    {reply, {error, already_started}, State};
handle_call({start_workers, _NumberOfWorkers, _WorkerConfig},
            _From, State = #state{dynamic = true}) ->
    {reply, {error, dynamic_workers}, State};
handle_call(dynamic_workers, _From, State = #state{workers = []}) ->
    {reply, ok, State#state{dynamic = true}};
handle_call(dynamic_workers, _From, State) ->
    {reply, {error, workers_already_started}, State};
handle_call({set_targets, Targets}, _From, State) ->
    {reply, ok, State#state{targets = Targets}};
handle_call(sync, _From, State) ->
    i_sync(State#state.worker_mod, State#state.workers),
    {reply, ok, State};
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
handle_cast({msg, unique, Msg}, State0 = #state{dynamic = true}) ->
    State1 = i_dynamic_cast(Msg, State0),
    {noreply, State1};
handle_cast({msg, _DistType, _Msg}, State = #state{workers = []}) ->
    {noreply, State};
handle_cast({msg, all, Msg}, State = #state{worker_mod = epw}) ->
    i_multicast(State#state.workers, Msg),
    {noreply, State};
handle_cast({msg, random, Msg}, State = #state{worker_mod = epw}) ->
    i_random_cast(State#state.workers, Msg),
    {noreply, State};
handle_cast({msg, keyhash, Msg}, State = #state{worker_mod = epw,
                                                dynamic = false}) ->
    i_keyhash_cast(State#state.workers, Msg),
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
i_sync(WorkerMod, Workers) ->
    lists:foreach(fun({Pid, _, _}) -> ok = WorkerMod:sync(Pid) end, Workers).

i_multicast(Workers, Msg) ->
    lists:foreach(fun({Pid, _, _}) -> epw:process(Pid, Msg) end, Workers).

i_random_cast(Workers, Msg) ->
    RandInt = random:uniform(length(Workers)),
    {WorkerPid, _, _} = lists:nth(RandInt, Workers),
    epw:process(WorkerPid, Msg).

i_keyhash_cast(Workers, Msg) ->
    Key = element(1, Msg),
    Hash = erlang:phash2(Key, length(Workers)) + 1,
    {WorkerPid, _, _} = lists:nth(Hash, Workers),
    epw:process(WorkerPid, Msg).

i_dynamic_cast(Msg, State0) ->
    Key = element(1, Msg),
    {WorkerPid, State1} =
        case lists:keyfind(Key, 3, State0#state.workers) of
            {WorkerPid0, _, Key} ->
                {WorkerPid0, State0};
            false ->
                i_dynamically_start_worker(Key, State0)
        end,
    epw:process(WorkerPid, Msg),
    State1.

i_dynamically_start_worker(Key, State) ->
    {WorkerPid,_, _} = Worker = i_start_worker(State, Key),
    {WorkerPid, State#state{workers = [Worker | State#state.workers]}}.

i_make_options(#state{targets = undefined}) ->
    [];
i_make_options(#state{targets = Targets}) ->
    [{targets, Targets}].

i_start_worker(State) ->
    [Worker] = i_start_workers(State, _NumberOfWorkers = 1),
    Worker.
i_start_worker(State, Key) ->
    [Worker] = i_start_workers(State, _NumberOfWorkers = 1),
    setelement(3, Worker, Key).

i_start_workers(State, NumberOfWorkers) ->
    i_start_workers(State, NumberOfWorkers, State#state.worker_config).
i_start_workers(State, NumberOfWorkers, WorkerConfig) ->
    i_start_workers(State#state.sup_pid, NumberOfWorkers,
                    WorkerConfig, i_make_options(State)).

i_start_workers(SupPid, NumberOfWorkers, WorkerConfig, Options) ->
    {ok, Workers} = pc_sup:start_workers(SupPid, NumberOfWorkers,
                                         WorkerConfig, Options),
    i_monitor_workers(Workers).

i_monitor_workers(Workers) ->
    lists:map(fun(Pid) ->
                      Ref = monitor(process, Pid),
                      {Pid, Ref, undefined}
              end, Workers).

i_restart_worker(OldPid, State = #state{dynamic = true}) ->
    Key = i_find_worker_key_by_pid(State#state.workers, OldPid),
    Worker = i_start_worker(State, Key),
    Workers = lists:keyreplace(OldPid, 1, State#state.workers, Worker),
    State#state{workers = Workers};
i_restart_worker(OldPid, State) ->
    NewWorker = i_start_worker(State),
    Workers = lists:keyreplace(OldPid, 1, State#state.workers, NewWorker),
    State#state{workers = Workers}.

i_find_worker_key_by_pid(Workers, Pid) ->
    {Pid, _, Key} = lists:keyfind(Pid, 1, Workers),
    Key.
