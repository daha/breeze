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
-module(epw_sup_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    {ok, Pid} = epw_sup:start_link(epw_dummy),
    ?assert(is_process_alive(Pid)),
    Expected = [{specs,1},
                {active,0},
                {supervisors,0},
                {workers,0}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    ok = epw_sup:stop(Pid).

start_worker_test() ->
    Pid = start(),

    ?assertMatch({ok, _Pid}, epw_sup:start_worker(Pid)),

    Expected = [{specs,1},
                {active,1},
                {supervisors,0},
                {workers,1}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    stop(Pid).


start_workers_test() ->
    Pid = start(),
    ?assertMatch({ok, [_Pid1, _Pid2]},
                 epw_sup:start_workers(Pid, 2)),
    Expected = [{specs,1},
                {active,2},
                {supervisors,0},
                {workers,2}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    stop(Pid).

% internal
start() ->
    {ok, Pid} = epw_sup:start_link(epw_dummy),
    Pid.

stop(Pid) ->
   epw_sup:stop(Pid).

-endif.
