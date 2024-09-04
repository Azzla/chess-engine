local Move = {}
--piece == 1-6 as corresponding piece ID
--color == 0 or 1 (1 is white, 0 is black)
--square_from == 1-64 as corresponding square from
--square_to == 1-64 as corresponding square to
--flags == optional table of special-case move flags:
--[[
	is_en_passant = false OR <square> (to capture)
	is_castle = false OR <rook_from, rook_to>
	is_promotion = false OR true
]]

function Move.new(square_from, square_to, flags)
	return {
		square_from,
		square_to,
		flags or {}
	}
end

return Move