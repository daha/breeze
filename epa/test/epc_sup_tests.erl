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

-module(epc_sup_tests).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    {ok, Pid} = epc_sup:start_link(),
    ?assert(is_process_alive(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(epc_sup)),
    Ref = monitor(process, Pid),
    ok = epc_sup:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(epc_sup)),
    ok = epc_sup:stop().

start_epc_epw_test() ->
    test_start_epc(epw_worker, epw, epw_dummy).

start_epc_eg_test() ->
    test_start_epc(eg_worker, eg, eg_dummy).

test_start_epc(Name, WorkerMod, WorkerCallback) ->
    {ok, Pid} = epc_sup:start_link(),
    Expected0 = [{specs, 1},
                 {active, 0},
                 {supervisors, 0},
                 {workers, 0}],
    ?assertEqual(Expected0, supervisor:count_children(Pid)),
    {ok, WorkerSup} = pc_sup:start_link(WorkerMod, WorkerCallback),
    {ok, _EpcPid} = epc_sup:start_epc(Name, WorkerMod, WorkerSup),
    Expected1 = [{specs, 1},
                 {active, 1},
                 {supervisors, 0},
                 {workers, 1}],
    ?assertEqual(Expected1, supervisor:count_children(Pid)),
    epc_sup:stop().
