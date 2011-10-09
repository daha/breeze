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

-module(pc_supersup_tests).

-include_lib("eunit/include/eunit.hrl").

-export([]).


start_stop_test() ->
    {ok, Pid} = pc_supersup:start_link(),
    ?assertNot(undefined == process_info(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(pc_supersup)),
    Ref = monitor(process, Pid),
    ok = pc_supersup:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(pc_supersup)),
    ok = pc_supersup:stop().

should_not_start_with_invalid_callback_module_test() ->
    pc_supersup:start_link(),
    WorkerMod = epw,
    CallbackModule = invalid_callback_module,
    ?assertEqual({error, {invalid_callback_module, CallbackModule}},
        pc_supersup:start_worker_sup(WorkerMod, CallbackModule)),
    pc_supersup:stop().


start_epw_worker_test() ->
    test_start_worker(epw, epw_dummy).

start_eg_worker_test() ->
    test_start_worker(eg, eg_dummy).

test_start_worker(WorkerMod, WorkerCallback) ->
    {ok, Pid} = pc_supersup:start_link(),
    Expected0 = [{specs, 1},
                 {active, 0},
                 {supervisors, 0},
                 {workers, 0}],
    ?assertEqual(Expected0, supervisor:count_children(Pid)),
    {ok, _WorkerSup} = pc_supersup:start_worker_sup(WorkerMod, WorkerCallback),
    Expected1 = [{specs, 1},
                 {active, 1},
                 {supervisors, 1},
                 {workers, 0}],
    ?assertEqual(Expected1, supervisor:count_children(Pid)),
    pc_supersup:stop().
