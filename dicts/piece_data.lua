local PieceData = {}

--[[
Here is a dictionary storing each piece type's possible move offsets,
as well as their value.  Offsets are used to calculate legal
moves in a given position, and values are used by the engine to determine
the relative strength of any position.
]]

PieceData[1] =
{
	name	= 'pawn',
	value	= 100,
	offsets	= {-40/4,-250/4},
	dimensions = {Assets.w.pawn:getWidth(),Assets.w.pawn:getHeight()},
	sliding	= false,
	[1] = {
		move_1 = {-8,-16},
		move = -8,
		move_cap = {-7,-9}
	}, --TODO: Can optimize slightly by multiplying moves by -1
	[0] = {
		move_1 = {8,16},
		move = 8,
		move_cap = {7,9}
	}
}

PieceData[2] =
{
	name	= 'knight',
	value	= 300,
	offsets	= {-380/4,-480/4},
	dimensions = {Assets.w.knight:getWidth(),Assets.w.knight:getHeight()},
	sliding	= false,
	move	= {6,10,15,17,-6,-10,-15,-17}
}

PieceData[3] =
{
	name	= 'bishop',
	value	= 325,
	offsets	= {-550/4,-550/4},
	dimensions = {Assets.w.bishop:getWidth(),Assets.w.bishop:getHeight()},
	sliding	= true,
	move	= {7,9,-7,-9}
}

PieceData[4] =
{
	name	= 'rook',
	value	= 500,
	offsets	= {-280/4,-400/4},
	dimensions = {Assets.w.rook:getWidth(),Assets.w.rook:getHeight()},
	sliding	= true,
	move	= {1,8,-1,-8}
}

PieceData[5] =
{
	name	= 'king',
	value	= 400,
	e_value	= 10000,
	offsets	= {-650/4,-680/4},
	dimensions = {Assets.w.king:getWidth(),Assets.w.king:getHeight()},
	sliding	= false,
	move	= {7,9,-7,-9,1,8,-1,-8}
}

PieceData[6] =
{
	name	= 'queen',
	value	= 900,
	offsets	= {-650/4,-460/4},
	dimensions = {Assets.w.queen:getWidth(),Assets.w.queen:getHeight()},
	sliding	= true,
	move	= {7,9,-7,-9,1,8,-1,-8}
}

return PieceData