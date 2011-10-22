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

-module(breeze_worker_controller_sup_tests).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    sup_tests_common:test_start_stop(breeze_worker_controller_sup).

start_worker_controller_processing_worker_test() ->
    test_start_worker_controller(processing_worker_worker,
				 breeze_processing_worker, pw_dummy).

start_worker_controller_generating_worker_test() ->
    test_start_worker_controller(generating_worker_worker,
				 breeze_generating_worker, gw_dummy).

test_start_worker_controller(Name, WorkerMod, WorkerCallback) ->
    {ok, Pid} = breeze_worker_controller_sup:start_link(),
    sup_tests_common:expect_one_spec_none_active(Pid),
    {ok, WorkerSup} = breeze_worker_sup:start_link(WorkerMod, WorkerCallback),
    {ok, _EpcPid} = breeze_worker_controller_sup:start_worker_controller(
		      Name, WorkerMod, WorkerSup),
    sup_tests_common:expect_one_active_worker(Pid),
    breeze_worker_controller_sup:stop().
