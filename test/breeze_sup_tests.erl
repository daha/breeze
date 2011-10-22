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

-module(breeze_sup_tests).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    sup_tests_common:test_start_stop(breeze_sup).

should_start_children_test() ->
    {ok, Pid} = breeze_sup:start_link(),
    Expected = [{specs, 3},
                {active, 3},
                {supervisors, 2},
                {workers, 1}],
    ?assertEqual(Expected, supervisor:count_children(Pid)),
    breeze_sup:stop().

should_stop_children_on_stop_test() ->
    {ok, Pid} = breeze_sup:start_link(),
    Children = supervisor:which_children(Pid),
    breeze_sup:stop(),
    ?assert(lists:all(fun({_,CPid,_,_}) -> undefined == process_info(CPid) end,
                      Children)).

should_get_application_env_test() ->
    meck:new(application, [unstick, passthrough]),
    {ok, _Pid} = breeze_sup:start_link(),
    ?assert(meck:called(application, get_all_env, [])),
    meck:unload(application),
    breeze_sup:stop().

should_pass_application_config_to_breeze_master_test() ->
    meck:new(application, [unstick, passthrough]),
    meck:new(breeze_master, [passthrough]),
    Config = [{topology, []}],
    meck:expect(application, get_all_env, 0, Config),
    {ok, _Pid} = breeze_sup:start_link(),
    ?assert(meck:called(breeze_master, start_link, [Config])),
    meck:unload(application),
    meck:unload(breeze_master),
    breeze_sup:stop().
