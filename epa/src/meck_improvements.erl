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
%% Addons to meck
%% @end

-module(meck_improvements).

%% API
-export([count_calls/3]).
-export([count_calls_wildcard/3]).

%%%===================================================================
%%% API functions
%%%===================================================================
count_calls(Mod, Fun, Args) ->
    i_count_calls({Mod, Fun, Args}, meck:history(Mod), 0).
count_calls_wildcard(Mod, Fun, Args) ->
    i_count_calls_wildcard({Mod, Fun, Args}, meck:history(Mod), 0).

%%%===================================================================
%%% Internal functions
%%%===================================================================
i_count_calls({_M, _F, _A}, [], Count) -> Count;
i_count_calls({M, F, A}, [{{M, F, A}, _Result} | Rest], Count) ->
    i_count_calls({M, F, A}, Rest, Count + 1);
i_count_calls({M, F, A}, [{{M, F, A}, _ExType, _Exp, _Stack} | Rest], Count) ->
    i_count_calls({M, F, A}, Rest, Count + 1);
i_count_calls({M, F, A}, [_Call | Rest], Count) ->
    i_count_calls({M, F, A}, Rest, Count).


i_count_calls_wildcard({_M, _F, _A}, [], Count) -> Count;
i_count_calls_wildcard({M, F, A}, [{{M, F, A}, _Result} | Rest], Count) ->
    i_count_calls_wildcard({M, F, A}, Rest, Count + 1);
i_count_calls_wildcard({M, F, A}, [{{M, F, A}, _ExType, _Exp, _Stack} | Rest], Count) ->
    i_count_calls_wildcard({M, F, A}, Rest, Count + 1);
i_count_calls_wildcard({M, F, A1}, [{{M, F, A2}, _Result} | Rest], Count) ->
    case i_match_args(A1, A2) of
        true ->
            i_count_calls_wildcard({M, F, A1}, Rest, Count + 1);
        false ->
            i_count_calls_wildcard({M, F, A1}, Rest, Count)
    end;
i_count_calls_wildcard({M, F, A1}, [{{M, F, A2}, _ExType, _Exp, _Stack} | Rest], Count) ->
    case i_match_args(A1, A2) of
        true ->
            i_count_calls_wildcard({M, F, A1}, Rest, Count + 1);
        false ->
            i_count_calls_wildcard({M, F, A1}, Rest, Count)
    end;
i_count_calls_wildcard({M, F, A}, [_Call | Rest], Count) ->
    i_count_calls_wildcard({M, F, A}, Rest, Count).

i_match_args([], []) ->
    true;
i_match_args([], _) ->
    false;
i_match_args([H1 | '_'], [H1 | _]) ->
    true;
i_match_args(['_'|R1], [_|R2]) ->
    i_match_args(R1, R2);
i_match_args([H1 | R1], [H1 | R2]) ->
    i_match_args(R1, R2);
i_match_args([_H1 | _R1], [_H2 | _R2]) ->
    false.
