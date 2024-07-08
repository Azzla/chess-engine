local Levels = {}

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

	^Lowercase = Enemy Pieces

	/ = New Row
	# = Barricade
	<number> = Empty Squares before/after a piece
]]

Levels[1] =
{
	name = "Tutorial",
	FEN = "4k3/4p3/8/8/8/8/8/7K1",
	points = 6
}

Levels[2] =
{
	name = "Catholic Brigade",
	FEN = "1pbkkbp1/2pbbp2/3pp3/8/8/8/8/3KK3",
	points = 12
}

return Levels