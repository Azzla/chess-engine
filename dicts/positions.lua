local Positions = {}

--Notes:--
--[[
	This game uses a modified version of FEN (Forsyth-Edwards Notation)
	for describing chess positions. Positions are transcribed
	left->right, top->down. Use the following key and see the
	parser for implementation details. 

	P = Pawn
	N = Knight
	B = Bishop
	R = Rook
	Q = Queen
	K = King

	^Lowercase = Black Pieces

	/ = New Row
	<number> = Empty Squares before/after a piece
]]

Positions[1] =
{
	name = "Default",
	FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
}

Positions[2] =
{
	name = "Castling-Test",
	FEN = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R"
}

Positions[3] =
{
	name = "Checkmate-Test",
	FEN = "4k3/pppppppp/8/8/8/8/8/QQQQKQQQ"
}

Positions[4] =
{
	FEN = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R"
}

return Positions