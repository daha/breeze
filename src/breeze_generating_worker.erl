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
%% TODO: merge this module with breeze_processing_worker

-module(breeze_generating_worker).

-behaviour(gen_server).

%% API
-export([start_link/3]).
-export([stop/1]).
-export([sync/1]).
-export([behaviour_info/1]).
-export([validate_module/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {
                callback,
                callback_state,
                targets,
                timeout
               }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link(Callback, CallbackArgs, Args) ->
%%           {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Callback, CallbackArgs, Args) ->
    gen_server:start_link(?MODULE, [Callback, CallbackArgs, Args], []).

stop(Server) ->
    gen_server:call(Server, stop).

behaviour_info(callbacks) ->
    [{init, 1},
     {generate, 2},
     {terminate, 2}];
behaviour_info(_Other) ->
    undefined.

validate_module(Module) ->
    try Exports = Module:module_info(exports),
        Missing = behaviour_info(callbacks) -- Exports,
        [] == Missing
    catch _:_ ->
              false
    end.

sync(Pid) ->
    gen_server:call(Pid, sync).

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
init([Callback, CallbackArgs, Args]) ->
    Targets = proplists:get_value(targets, Args, []),
    {ok, CallbackState} = Callback:init(CallbackArgs),
    Timeout = case Targets of
                  [] -> infinity;
                  _ -> 0
              end,
    State = #state{callback = Callback,
                   callback_state = CallbackState,
                   targets = Targets,
                   timeout = Timeout},
    {ok, State, State#state.timeout}.

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
handle_call(sync, _From, State) ->
    {reply, ok, State, State#state.timeout};
handle_call(stop, _From, State) ->
    Callback = State#state.callback,
    CallbackState = Callback:terminate(normal, State#state.callback_state),
    {stop, normal, {ok, CallbackState}, State};
handle_call(Request, _From, State) ->
    {reply, {error, {invalid_request, Request}}, State, State#state.timeout}.

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
    {noreply, State, State#state.timeout}.

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
handle_info(timeout, State) ->
    Callback = State#state.callback,
    EmitFun = i_make_emit_fun(State#state.targets),
    {ok, CallbackState} = Callback:generate(EmitFun,
                                            State#state.callback_state),
    {noreply, State#state{callback_state = CallbackState}, State#state.timeout};
handle_info(_Info, State) ->
    {noreply, State, State#state.timeout}.

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
i_make_emit_fun(Targets) ->
    fun(Msg) -> lists:foreach(
                  fun({Pid, all}) ->
                          breeze_worker_controller:multicast(Pid, Msg);
                     ({Pid, random}) ->
                          breeze_worker_controller:random_cast(Pid, Msg);
                     ({Pid, keyhash}) ->
                          breeze_worker_controller:keyhash_cast(Pid, Msg);
                     ({Pid, dynamic}) ->
                          breeze_worker_controller:dynamic_cast(Pid, Msg)
                  end, Targets)
    end.
