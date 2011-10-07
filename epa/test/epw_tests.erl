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

-module(epw_tests).

-include_lib("eunit/include/eunit.hrl").

% Tests
start_stop_test() ->
    Mock = create_mock(),
    {ok, Pid} = epw:start_link(Mock, [], []),
    ?assertNot(undefined == process_info(Pid)),
    {ok, _} = epw:stop(Pid),
    delete_mock(Mock).

stop_should_return_the_state_test() ->
    [Pid, Mock, StateRef] = setup(),
    ?assertEqual({ok, StateRef}, epw:stop(Pid)),
    delete_mock(Mock).

should_call_terminate_on_stop_test() ->
    [Pid, Mock, StateRef] = setup(),
    epw:stop(Pid),
    ?assert(meck:called(Mock, terminate, [normal, StateRef])),
    delete_mock(Mock).

behaviour_info_test() ->
    Expected = [{init,1},
                {process, 3},
                {terminate,2}],
    Actual = epw:behaviour_info(callbacks),
    ?assertEqual(Expected, Actual),
    ?assertEqual(undefined, epw:behaviour_info(foo)).

validate_module_test() ->
    Mock = create_mock(),
    NotValidModule = not_valid_module,
    meck:new(NotValidModule),
    ?assertNot(epw:validate_module(NotValidModule)),
    ?assert(epw:validate_module(Mock)),
    delete_mock(Mock),
    delete_mock(NotValidModule).

mocked_tests_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} || T <- [fun should_call_init_/1,
			   fun should_handle_sync_/1,
			   fun should_call_process_/1
			  ]]}.

should_call_init_([_Pid, Mock, StateRef]) ->
    ?assert(meck:called(Mock, init, [StateRef])).

should_handle_sync_([Pid | _]) ->
    meck:new(epw, [passthrough]),
    ok = epw:sync(Pid),
    ?assertEqual(1, meck_improvements:count_calls_wildcard(
		      epw, handle_call, [sync | '_'])),
    meck:unload(epw).

should_call_process_([Pid, Mock, StateRef]) ->
    MessageRef = make_ref(),
    ok = epw:process(Pid, MessageRef),
    epw:sync(Pid), % Sync with the process to make sure it has processed
    ?assertEqual(1, meck_improvements:count_calls_wildcard(
                   Mock, process, [MessageRef, '_', StateRef])).

% Helper functions
setup() ->
    Mock = create_mock(),
    StateRef = make_ref(),
    {ok, Pid} = epw:start_link(Mock, StateRef, []),
    [Pid, Mock, StateRef].

teardown([Pid, Mock | _]) ->
    epw:stop(Pid),
    delete_mock(Mock).

create_mock() ->
    Mock = epw_mock,
    meck:new(Mock),
    meck:expect(Mock, init, fun(State) -> {ok, State} end),
    meck:expect(Mock, process, fun(_Msg, _EmitFun, State) -> {ok, State} end),
    meck:expect(Mock, terminate, fun(_Reason, State) -> State end),
    Mock.

delete_mock(Mock) ->
    catch meck:unload(Mock).
