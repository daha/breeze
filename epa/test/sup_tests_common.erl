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

-module(sup_tests_common).

-include_lib("eunit/include/eunit.hrl").

-export([test_start_stop/1]).
-export([expect_one_spec_none_active/1]).
-export([expect_one_active_supervisor/1]).
-export([expect_one_active_worker/1]).
-export([expect_supervisor_children/3]).

test_start_stop(Mod) ->
    {ok, Pid} = Mod:start_link(),
    ?assert(is_process_alive(Pid)),
    ?assertMatch(Pid when is_pid(Pid), whereis(Mod)),
    Ref = monitor(process, Pid),
    ok = Mod:stop(),
    receive {'DOWN', Ref, process, _, _} -> ok end,
    ?assert(undefined == process_info(Pid)),
    ?assertEqual(undefined, whereis(Mod)),
    ok = Mod:stop().

expect_one_spec_none_active(SupervisorPid) ->
    expect_supervisor_children(SupervisorPid, _Supervisors = 0, _Workers = 0).

expect_one_active_worker(SupervisorPid) ->
    expect_supervisor_children(SupervisorPid, _Supervisors = 0, _Workers = 1).

expect_one_active_supervisor(SupervisorPid) ->
    expect_supervisor_children(SupervisorPid, _Supervisors = 1, _Workers = 0).

expect_supervisor_children(SupervisorPid, Supervisors, Workers) ->
    Expected0 = [{specs, 1},
                 {active, Supervisors + Workers},
                 {supervisors, Supervisors},
                 {workers, Workers}],
    ?assertEqual(Expected0, supervisor:count_children(SupervisorPid)).
