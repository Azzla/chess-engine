local Move = {}
Move.__index = Move
--piece == 1-6 as corresponding piece ID
--color == 0 or 1 (1 is white, 0 is black)
--square_from == 1-64 as corresponding square from
--square_to == 1-64 as corresponding square to
--flags == optional table of special-case move flags:
--[[
	is_capture = <boolean>
	first_move = <boolean>
	is_en_passant = false OR <square> (to capture)
	is_castle = false OR <rook_from, rook_to>
	is_promotion = false OR <square> (to promote)
]]

function Move.new(square_from, square_to, flags)
	local move = {square_from, square_to, flags or {}}
	if not flags then move[3].is_capture = false end
	return setmetatable(move, Move)
end

return Move