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

-module(breeze_eg_tests).

-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

% used by pc_tests_common
-export([tested_module/0]).
-export([create_mock/0]).

% Exported functions
tested_module() ->
    breeze_eg.

create_mock() ->
    Mock = eg_mock,
    meck:new(Mock),
    meck:expect(Mock, init, fun(State) -> {ok, State} end),
    meck:expect(Mock, generate, fun(_EmitFun, State) -> {ok, State} end),
    meck:expect(Mock, terminate, fun(_Reason, State) -> State end),
    Mock.

% Tests in pc_tests_common
start_stop_test() ->
    pc_tests_common:test_start_stop(?MODULE), ok.

should_return_the_state_in_stop_test() ->
    pc_tests_common:should_return_the_state_in_stop(?MODULE), ok.

should_call_terminate_on_stop_test() ->
    pc_tests_common:should_call_terminate_on_stop(?MODULE), ok.

behaviour_info_test() ->
    Expected = [{init, 1},
                {generate, 2},
                {terminate, 2}],
    pc_tests_common:test_behaviour_info(?MODULE, Expected), ok.

validate_module_test() ->
    pc_tests_common:validate_module(?MODULE), ok.

mocked_tests_test_() ->
    pc_tests_common:mocked_tests(?MODULE).

verify_emitted_message_is_multicasted_to_all_targets_test() ->
    verify_emitted_message_is_sent_to_all_targets(multicast, all), ok.
verify_emitted_message_is_random_casted_to_all_targets_test() ->
    verify_emitted_message_is_sent_to_all_targets(random_cast, random), ok.
verify_emitted_message_is_keyhash_casted_to_all_targets_test() ->
    verify_emitted_message_is_sent_to_all_targets(keyhash_cast, keyhash), ok.
verify_emitted_message_is_dynamically_casted_to_all_targets_test() ->
    verify_emitted_message_is_sent_to_all_targets(dynamic_cast, dynamic), ok.

verify_emitted_message_is_sent_to_all_targets(EpcEmitFunc, DistributionKey) ->
    Msg = {foo, bar},
    EmitTriggerFun = fun(_Pid) -> noop end,
    EmitTriggerMock = make_emitting_generate_mock(Msg),
    pc_tests_common:verify_emitted_message_is_sent_to_all_targets(
      ?MODULE, EmitTriggerMock, EmitTriggerFun, Msg, EpcEmitFunc,
      DistributionKey).


% Local tests
should_set_the_timer_after_every_message_test_() ->
    {foreach, fun setup_timer_tests/0, fun teardown_timer_tests/1,
     [{with, [T]} ||
      T <- [
            fun ?MODULE:should_have_timeout_after_init_/1,
            fun ?MODULE:should_have_timeout_after_timeout_/1,
            fun ?MODULE:should_have_timeout_after_sync_/1,
            fun ?MODULE:should_have_timeout_after_handle_call_/1,
            fun ?MODULE:should_have_timeout_after_handle_cast_/1,
            fun ?MODULE:should_have_timeout_after_handle_info_/1
            ]
     ]}.

should_have_timeout_after_init_([_Pid, Target, Msg | _]) ->
    verify_continuous_timeouts(Target, Msg), ok.

should_have_timeout_after_timeout_([Pid, Target, Msg | _]) ->
    breeze_eg:sync(Pid),
    PreCount = meck:num_calls(breeze_epc, multicast, [Target, Msg]),
    timer:sleep(1), % enough time to make a number of calls
    % The counter must increase with more then one, since increase
    % with only one indicate no timeout after handling timeout.
    ?assert((PreCount + 1) < meck:num_calls(breeze_epc, multicast,
					    [Target, Msg])).

should_have_timeout_after_sync_([Pid, Target, Msg | _]) ->
    breeze_eg:sync(Pid),
    verify_continuous_timeouts(Target, Msg), ok.

should_have_timeout_after_handle_call_([Pid, Target, Msg | _]) ->
    gen_server:call(Pid, random_data()),
    verify_continuous_timeouts(Target, Msg), ok.

should_have_timeout_after_handle_cast_([Pid, Target, Msg | _]) ->
    gen_server:cast(Pid, random_data()),
    verify_continuous_timeouts(Target, Msg), ok.

should_have_timeout_after_handle_info_([Pid, Target, Msg | _]) ->
    Pid ! random_data(),
    verify_continuous_timeouts(Target, Msg), ok.

% Helper to the timeout tests
verify_continuous_timeouts(Target, Msg) ->
    PreCount = meck:num_calls(breeze_epc, multicast, [Target, Msg]),
    timer:sleep(1), % enough time to make a number of calls
    ?assert(PreCount < meck:num_calls(breeze_epc, multicast, [Target, Msg])).

%% Internal functions
make_emitting_generate_mock(Msg) ->
    fun(Mock) ->
            meck:expect(Mock, generate,
                        fun(EmitFun, State) ->
                                EmitFun(Msg),
                                {ok, State}
                        end)
    end.

setup_timer_tests() ->
    Mock = create_mock(),
    Msg = {foo, bar},
    EmitTriggerMock = make_emitting_generate_mock(Msg),
    EmitTriggerMock(Mock),
    Target = pc_tests_common:create_pid(),
    Targets = [{Target, all}],
    meck:new(breeze_epc),
    meck:expect(breeze_epc, multicast, 2, ok),
    {ok, Pid} = breeze_eg:start_link(Mock, [], [{targets, Targets}]),
    [Pid, Target, Msg, Mock].

teardown_timer_tests([Pid, _Target, _Msg, Mock]) ->
    breeze_eg:stop(Pid),
    pc_tests_common:delete_mock(breeze_epc),
    pc_tests_common:delete_mock(Mock),
    ok.

random_data() ->
    {foo, make_ref(), self(), [1]}.
