local FENParser = {}

--p = {'b','pawn'},		P = {'w','pawn'},
--n = {'b','knight'},	N = {'w','knight'},
--b = {'b','bishop'},	B = {'w','bishop'},
--r = {'b','rook'},		R = {'w','rook'},
--k = {'b','king'},		K = {'w','king'},
--q = {'b','queen'},	Q = {'w','queen'}

local key = {
	p = {0,1},	P = {1,1},
	n = {0,2},	N = {1,2},
	b = {0,3},	B = {1,3},
	r = {0,4},	R = {1,4},
	k = {0,5},	K = {1,5},
	q = {0,6},	Q = {1,6}
}

--WARNING: This function mutates the board state passed in.
function FENParser.parse(fen, board)
	assert(type(fen) == "string", "FEN codes must be a valid Lua string.")
	
	local current_square = 1

	for token in string.gmatch(fen, "[^%/]+") do
		if #token > 1 then --this row contains some units
			for i=1,#token do
				local c = token:sub(i,i)
				local num_c = tonumber(c)
				--this character defines squares preceeding a unit
				if num_c then current_square = current_square + num_c
				else
					board.board_loyalty[current_square] = key[c][1]
					board.board_pieces[current_square] = key[c][2]
					
					--record the king position
					if key[c][2] == 5 then
						board.king[key[c][1]] = current_square
						if current_square == 5 and key[c][1] == 0 then
							board.board_first_move[current_square] = 1
						end
						if current_square == 61 and key[c][1] == 1 then
							board.board_first_move[current_square] = 1
						end
					end

					--record pawn first move hash
					if key[c][2] == 1 then
						if key[c][1] == 0 and current_square >=9 and current_square <= 16 then
							board.board_first_move[current_square] = 1
						end
						if key[c][1] == 1 and current_square >=49 and current_square <= 56 then
							board.board_first_move[current_square] = 1
						end
					end

					--record rook first move hash (probably TODO)
					if key[c][2] == 4 then
						if key[c][1] == 0 and (current_square == 1 or current_square == 8) then
							board.board_first_move[current_square] = 1
						end
						if key[c][1] == 1 and (current_square == 57 or current_square == 64) then
							board.board_first_move[current_square] = 1
						end
					end
					
					current_square = current_square + 1
				end
			end			
		else --this row only has empty space
			current_square = current_square + 8
		end
	end
end

return FENParser