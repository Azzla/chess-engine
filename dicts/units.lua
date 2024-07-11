local Units = {}

--[[
Here is a dictionary storing each piece type's possible move offsets,
as well as their value.  Offsets are used to calculate legal
moves in a given position, and values are used by the engine to determine
the relative strength of any position.
]]

Units.pawn =
{
	_id		= 1,
	value	= 100,
	sliding	= false,
	w = {
		move_1 = {-8,-16},
		move = {-8},
		move_cap = {-7,-9}
	},
	b = {
		move_1 = {8,16},
		move = {8},
		move_cap = {7,9}
	}
}

Units.knight =
{
	_id		= 2,
	value	= 300,
	sliding	= false,
	move	= {6,10,15,17,-6,-10,-15,-17}
}

Units.bishop =
{
	_id		= 3,
	value	= 325,
	sliding	= true,
	move	= {7,9,-7,-9}
}

Units.rook =
{
	_id		= 4,
	value	= 500,
	sliding	= true,
	move	= {1,8,-1,-8}
}

Units.king =
{
	_id		= 5,
	value	= 400,
	e_value	= 10000,
	sliding	= false,
	move	= {7,9,-7,-9,1,8,-1,-8}
}

Units.queen =
{
	_id		= 6,
	value	= 900,
	sliding	= true,
	move	= {7,9,-7,-9,1,8,-1,-8}
}

return Units