%%%-------------------------------------------------------------------
%%% @doc Wikidata structured knowledge entity search agent.
%%%
%%% Queries the Wikidata API for entities matching a search term and
%%% returns embryos with the entity URL, label, and description.
%%%
%%% Deduplication by URL is handled upstream by the Emquest pipeline.
%%%
%%% === Capability cascade ===
%%%
%%%   base_capabilities/0 extends em_filter:base_capabilities().
%%%
%%% Handler contract: handle/2 (Body, Memory) -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(wikidata_filter_app).
-behaviour(application).

-export([start/2, stop/1]).
-export([handle/2, base_capabilities/0]).

-define(SEARCH_URL,
    "https://www.wikidata.org/w/api.php"
    "?action=wbsearchentities&format=json&language=en"
    "&search=").

%%====================================================================
%% Capability cascade
%%====================================================================

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"wikidata">>, <<"knowledge">>,
                                      <<"structured">>, <<"entities">>].

%%====================================================================
%% Application behaviour
%%====================================================================

start(_Type, _Args) ->
    em_filter:start_agent(wikidata_filter, ?MODULE, #{
        capabilities => base_capabilities()
    }),
    {ok, self()}.

stop(_State) ->
    em_filter:stop_agent(wikidata_filter).

%%====================================================================
%% Agent handler
%%====================================================================

handle(Body, Memory) when is_binary(Body) ->
    {generate_embryo_list(Body), Memory};
handle(_Body, Memory) ->
    {[], Memory}.

%%====================================================================
%% Search and processing
%%====================================================================

generate_embryo_list(JsonBinary) ->
    {Query, Timeout} = extract_params(JsonBinary),
    fetch_results(Query, Timeout).

extract_params(JsonBinary) ->
    try json:decode(JsonBinary) of
        Map when is_map(Map) ->
            Query   = binary_to_list(maps:get(<<"value">>, Map,
                          maps:get(<<"query">>, Map, <<"">>))),
            Timeout = case maps:get(<<"timeout">>, Map, undefined) of
                undefined            -> 10;
                T when is_integer(T) -> T;
                T when is_binary(T)  -> binary_to_integer(T)
            end,
            {Query, Timeout};
        _ ->
            {binary_to_list(JsonBinary), 10}
    catch
        _:_ -> {binary_to_list(JsonBinary), 10}
    end.

fetch_results("", _) -> [];
fetch_results(Query, Timeout) ->
    Url = lists:flatten(io_lib:format("~s~s", [?SEARCH_URL, uri_string:quote(Query)])),
    Headers = [{"User-Agent", "wikidata_filter/1.0"}],
    case httpc:request(get, {Url, Headers},
                       [{timeout, Timeout * 1000},
                        {ssl, [{verify, verify_none}]}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} ->
            parse_results(Body);
        _ ->
            []
    end.

parse_results(JsonBin) ->
    try json:decode(JsonBin) of
        #{<<"search">> := Results} when is_list(Results) ->
            lists:filtermap(fun build_embryo/1, Results);
        _ ->
            []
    catch
        _:_ -> []
    end.

build_embryo(Entity) ->
    Id    = maps:get(<<"id">>,          Entity, <<"">>),
    Label = maps:get(<<"label">>,       Entity, Id),
    Desc  = maps:get(<<"description">>, Entity, <<"">>),
    Url   = maps:get(<<"url">>,         Entity,
                list_to_binary("https://www.wikidata.org/wiki/" ++ binary_to_list(Id))),
    case Id of
        <<"">> -> false;
        _ ->
            {true, #{
                <<"properties">> => #{
                    <<"url">>    => Url,
                    <<"resume">> => Desc,
                    <<"title">>  => Label,
                    <<"id">>     => Id,
                    <<"source">> => <<"www.wikidata.org">>
                }
            }}
    end.
