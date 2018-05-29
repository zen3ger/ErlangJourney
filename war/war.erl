-module(war).
-export([shuffle/1, shuffle/2, table/1, game_manager/3, play/0, player/1, player/2]).
-author("Roland Kovacs <zen3ger@gmail.com>").


%%
%% Create simple deck where J->10, Q->11, K->12, A->13
%%
deck() ->
	[ {T, V} || T <- ["Club", "Diamond", "Heart", "Spade"],
				V <- lists:seq(1,13) ].

%%
%% Simple alg to shuffle the cards
%%
shuffle(Deck) ->
	shuffle(Deck, []).

% Last card should be just randomly inserted, than return the shuffled deck
shuffle([Card], Acc) ->
	{P1, P2} = lists:split(length(Acc), Acc),
	P1 ++ [Card | P2];
shuffle(Deck, Acc) ->
	% split the deck at any random point
	% NOTE: the Deck should never be [], as previous pattern catches the Deck in
	%       the previous state. This is needed as rand:uniform(0) would throw an exeption
	{Leading, [H | T]} = lists:split(rand:uniform(length(Deck)-1), Deck),
	shuffle(Leading ++ T, [H | Acc]).

%%
%% function to keep track of the state of the table (aka. the stack of cards)
%%
table([]) ->
	% When the table is empty the game either finished, or
	% waiting for the next round of cards to be placed.
	receive
		done ->
			done;
		{GameManager, Card} ->
			GameManager ! next,
			table([Card])
	end;
table(Cards) ->
	receive
		done ->
			done;
		{GameManager, Card} when (length(Cards) rem 2) =/= 0 ->
			% When there is en odd number of cards on the table,
			% getting the next card would mean that we need to check if
			% if any of the players won the round...
			{_, Val} = Card,
			[{_, PrevVal} | _] = Cards,
			if
				Val > PrevVal ->
					GameManager ! {take, [Card | Cards]},
					table([]);
				Val < PrevVal ->
					GameManager ! {prevtake, [Card | Cards]},
					table([]);
				Val == PrevVal ->
					GameManager ! next,
					table([Card | Cards])
			end;
		{GameManager, Card} ->
			NewCards = [Card | Cards],
			GameManager ! next,
			table(NewCards)
	end.

%%
%% The game_manager process passes the Cards between table and player
%% and keeeps track of the order of players...
%%
game_manager(Player, NextPlayer, Table) ->
	receive
		done ->
			io:format("Sorry, the fun times are gone...\n"),
			Table ! NextPlayer ! Player ! done;
		init ->
			Self = self(),
			Player ! {Self, init},
			NextPlayer ! {Self, init},
			Player ! place,
			game_manager(Player, NextPlayer, Table);
		{Player, done} ->
			io:format("~p WON!\n", [NextPlayer]),
			NextPlayer ! Table ! done;
		{Player, Card} ->
			io:format("~p: placed ~p~n", [Player, Card]),
			Table ! {self(), Card},
			receive
				{take, Cards} ->
					io:format("~p: took ~p~n", [Player, Cards]),
					Player ! {take, Cards};
				{prevtake, Cards} ->
					io:format("~p: took ~p~n", [NextPlayer, Cards]),
					NextPlayer ! {take, Cards};
				next -> ok
			end,
			NextPlayer ! place,
			game_manager(NextPlayer, Player, Table)
	end.

%%
%% A player process either takes a bunch of card or sends
%% a card to the manager
%%
player(Hand) ->
	receive
		done ->
			done;
		{GameManager, init} ->
			player(GameManager, Hand);
		_ ->
			player(Hand)
	end.

player(GameManager, Hand) ->
	receive
		done ->
			done;
		place when Hand == [] ->
			GameManager ! {self(), done};
		place ->
			[Card | Rest] = Hand,
			GameManager ! {self(), Card},
			player(GameManager, Rest);
		{take, Cards} ->
			NewHand = shuffle(Hand ++ Cards),
			player(GameManager, NewHand)
	end.


%%
%% Let's play WAR!
%%
play() ->
	Deck = shuffle(deck()),
	{HandA, HandB} = lists:split(length(Deck) div 2, Deck),
	PlayerA = spawn(fun () -> player(HandA) end),
	PlayerB = spawn(fun () -> player(HandB) end),
	Table = spawn(fun () -> table([]) end),
	GameManager = spawn(fun () -> game_manager(PlayerA, PlayerB, Table) end),
	GameManager ! init,
	ok.
