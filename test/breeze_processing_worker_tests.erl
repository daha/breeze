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

-module(breeze_processing_worker_tests).

-include_lib("eunit/include/eunit.hrl").

% used by pc_tests_common
-export([tested_module/0]).
-export([create_mock/0]).

% Exported functions
tested_module() ->
    breeze_processing_worker.

create_mock() ->
    Mock = processing_worker_mock,
    meck:new(Mock),
    meck:expect(Mock, init, fun(State) -> {ok, State} end),
    meck:expect(Mock, process, fun(_Msg, _EmitFun, State) -> {ok, State} end),
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
                {process, 3},
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

verify_emitted_message_is_sent_to_all_targets(EpcEmitFunc, DistKey) ->
    Msg = {foo, bar},
    EmitTriggerFun = fun(Pid) -> breeze_processing_worker:process(Pid, Msg) end,
    EmitTriggerMock =
        fun(Mock) ->
                meck:expect(Mock, process,
                            fun(ProcessMsg, EmitFun, State) ->
                                    EmitFun(ProcessMsg),
                                    {ok, State}
                            end)
        end,
    pc_tests_common:verify_emitted_message_is_sent_to_all_targets(
      ?MODULE, EmitTriggerMock, EmitTriggerFun, Msg, EpcEmitFunc, DistKey).
