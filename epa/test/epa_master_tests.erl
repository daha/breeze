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

-module(epa_master_tests).

-include_lib("eunit/include/eunit.hrl").

-export([]).

start_stop_test() ->
    {ok, Pid} = epa_master:start_link([]),
    ?assertNot(undefined == process_info(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(epa_master)),
    Ref = monitor(process, Pid),
    ok = epa_master:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(epa_master)).

read_simple_config_and_start_epc_test() ->
    mock(),

    WorkerCallback = epw_dummy,
    Config = [{topology, [{dummy, epw, WorkerCallback, 2, []}]}],

    {ok, _Pid} = epa_master:start_link(Config),

    ?assert(meck:called(epw_sup_master, start_worker_sup, [WorkerCallback])),
    ?assert(meck:called(epc_sup, start_epc, [self()])),
    teardown().

read_config_with_two_connected_epcs_test() ->
    mock(),

    SenderCallback = sender_callback,
    ReceiverCallback = receiver_callback,
    Config = [{topology, [{sender, epw, SenderCallback, 2, [{receiver, all}]},
                          {receiver, epw, ReceiverCallback, 2, []}
                         ]
              }],

    {ok, _Pid} = epa_master:start_link(Config),

    ?assert(meck:called(epw_sup_master, start_worker_sup, [SenderCallback])),
    ?assert(meck:called(epw_sup_master, start_worker_sup, [ReceiverCallback])),
    ?assertEqual(2, meck_improvements:count_calls(epc_sup, start_epc, [self()])),
    ?assert(meck:called(epc, set_targets, [self(), [{self(), all}]])),
    teardown().

%% Internal functions
mock() ->
    meck:new(epw_sup_master),
    meck:new(epc_sup),
    meck:new(epc),
    meck:expect(epw_sup_master, start_worker_sup, 1, {ok, self()}),
    meck:expect(epc_sup, start_epc, 1, {ok, self()}),
    meck:expect(epc, set_targets, 2, ok).

teardown() ->
    unload_mocks(),
    epa_master:stop().

unload_mocks() ->
    meck:unload(epc),
    meck:unload(epc_sup),
    meck:unload(epw_sup_master).

