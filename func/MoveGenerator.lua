local MoveData,KnightData,DirectionOffsets = require('dicts.move_data')()
--local Move = require('class.Move')
local MoveGenerator = {}

local function table_shallow_copy(t) return {unpack(t)} end
local all_files = {
	['a'] = {1,9,17,25,33,41,49,57},
	['b'] = {2,10,18,26,34,42,50,58},
	['c'] = {3,11,19,27,35,43,51,59},
	['d'] = {4,12,20,28,36,44,52,60},
	['e'] = {5,13,21,29,37,45,53,61},
	['f'] = {6,14,22,30,38,46,54,62},
	['g'] = {7,15,23,31,39,47,55,63},
	['h'] = {8,16,24,32,40,48,56,64}
}
local ranks = {
	[1] = {57,64},
	[2] = {49,56},
	[3] = {41,48},
	[4] = {33,40},
	[5] = {25,32},
	[6] = {17,24},
	[7] = {9,16},
	[8] = {1,8}
}
local blank_board = {
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0		
}

function MoveGenerator:init(board, move_log)
	self._board				= board --reference
	self.board				= self._board.board_pieces
	self.loyalty			= self._board.board_loyalty
	self.first_moves		= self._board.board_first_move
	self.king				= self._board.king
	self.legal_moves		= {}
	self.attacks			= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}
	self.last_move_pawn		= nil
	self.color_to_move		= board.color_to_move
	self.made_first_move	= false
	self.checkmate			= nil
end

function MoveGenerator:thread_init()
	self.board				= {}
	self.loyalty			= {}
	self.first_moves		= {}
	self.king				= {[0] = 5, [1] = 61}
	self.attacks			= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}
	self.legal_moves		= {}
	self.last_move_pawn		= nil
	self.color_to_move		= 0
	self.checkmate			= nil
	self.move_log			= {}
end

function MoveGenerator:thread_supply(pieces, loyalty, first_moves, b_king, w_king)
	self.board				= pieces
	self.loyalty			= loyalty
	self.first_moves		= first_moves
	self.king				= {[0] = b_king, [1] = w_king}
end

function MoveGenerator:generate_pseudo_legal_moves()
	local moves = {}
	local color = self.color_to_move
	self.attacks[color] = table_shallow_copy(blank_board)

	for square,piece in ipairs(self.board) do
		if self.loyalty[square] ~= color then goto continue end
		if piece == 0 then goto continue end

		if piece == 1 then
			self:pawn_move(square, color, self.first_moves[square], moves)
		end
		if piece == 2 then
			self:knight_move(square, color, moves)
		end
		if piece == 5 then
			self:king_move(square, color, self.first_moves[self.king[color]], moves)
		end
		if piece == 3 or piece == 4 or piece == 6 then
			self:sliding_move(square, color, piece, moves)
		end

		::continue::
	end

	return moves
end

function MoveGenerator:generate_legal_moves(moves)
	local legal_moves = {}
	local king_color = self.color_to_move
	for _,move in ipairs(moves) do
		self:make_move(move)
		if not self:is_in_check(king_color) then legal_moves[#legal_moves+1] = move end
		self:unmake_move(move)
	end
	if #legal_moves == 0 then self.checkmate = king_color end
	return legal_moves
end

function MoveGenerator:generate_captures(moves)
	local captures = {}
	for _,move in ipairs(moves) do
		local square_to = move[2]
		if self.board[square_to] ~= 0 then captures[#captures+1] = move end
	end
	return captures
end

function MoveGenerator:is_in_check(king_col, optional_square)
	local king_squ = optional_square or self.king[king_col]
	local knight_attacks = KnightData[king_squ]
	local direct_attacks = MoveData[king_squ]
	local knight_checks = {}
	local direct_checks = {}

	for _,square in ipairs(knight_attacks) do
		local is_knight = self.board[square] == 2
		local is_enemy = self.loyalty[square] == 1-king_col
		if is_knight and is_enemy then table.insert(knight_checks,square) end
	end

	local start_dir,end_dir = 1,8
	for dir=start_dir,end_dir do
		if direct_attacks[dir] == 0 then goto continue end
		for i=1,direct_attacks[dir] do

			local square_from = king_squ + DirectionOffsets[dir] * i
			local square_loyalty = self.loyalty[square_from]

			if square_loyalty == king_col then goto continue else
				if square_loyalty == 1-king_col then
					local piece = self.board[square_from]
					--ray blocks
					if piece == 2 then goto continue end
					if piece == 3 and dir <= 4 then goto continue end
					if piece == 4 and dir >= 5 then goto continue end
					
					local is_pawn = piece == 1
					local pawn_cap = {7-14*king_col,9-18*king_col}
					local is_pawn_check = is_pawn
						and (DirectionOffsets[dir] == pawn_cap[1] or DirectionOffsets[dir] == pawn_cap[2])
						and i == 1
					if is_pawn and not is_pawn_check then goto continue
					elseif is_pawn_check then
						--table.insert(direct_checks, {square_from, piece, dir})
						table.insert(direct_checks, 1)
					end
					
					if piece == 5 and i == 1 then --king "check"
						table.insert(direct_checks, 1)
						goto continue
					elseif piece == 5 then goto continue end

					if piece == 6 then --queen check
						--table.insert(direct_checks, {square_from, piece, dir})
						table.insert(direct_checks, 1)
						goto continue
					end

					local is_bish_check = piece == 3 and dir >= 5
					local is_rook_check = piece == 4 and dir <= 4
					if is_bish_check or is_rook_check then
						--table.insert(direct_checks, {square_from, piece, dir})
						table.insert(direct_checks, 1)
					end
				end
			end
		end
		::continue::
	end
	
	if #knight_checks>0 or #direct_checks>0 then return true end
	return false
end

function MoveGenerator:make_move(move)
	local square_from,square_to = move[1],move[2]
	local flags = move[3]
	
	--record the board state before this move was made
	move[3].undo_move = {
		self.board[square_to],
		self.board[square_from],
		self.first_moves[square_from],
		self.first_moves[square_to],
		self.loyalty[square_from],
		self.loyalty[square_to],
		self.king[self.color_to_move]
	}
	if flags.is_en_passant then
		move[3][8] = self.board[flags.is_en_passant]
		move[3][9] = self.loyalty[flags.is_en_passant]
	elseif flags.is_castle then
		local rook_from = flags.is_castle[1]
		local rook_to = flags.is_castle[2]
		move[3][8] = {
			self.board[rook_to],
			self.board[rook_from],
			self.first_moves[rook_from],
			self.first_moves[rook_to],
			self.loyalty[rook_from],
			self.loyalty[rook_to]
		}
	end
	---------------------------------------------------------
	---------------------------------------------------------
	--if it's a pawn, check for passant and record the move
	if self.board[square_from] == 1 then
		self.last_move_pawn = {square_to, math.abs(square_to-square_from)}
		if flags.is_en_passant then
			self.board[flags.is_en_passant] = 0
			self.loyalty[flags.is_en_passant] = -1
		end
	else
		self.last_move_pawn = nil
	end
	--if it's a king, check for castling and record the king's new position
	if self.board[square_from] == 5 then
		if flags.is_castle then
			local rook_from = flags.is_castle[1]
			local rook_to = flags.is_castle[2]
			self:castle(rook_from,rook_to)
		end
		self.king[self.color_to_move] = square_to
	end

	--reflect the move on the board state
	if flags.is_promotion then
		self.board[square_to] = flags.is_promotion
	else
		self.board[square_to] = self.board[square_from]
	end
	self.board[square_from]			= 0
	self.first_moves[square_from]	= 0
	self.first_moves[square_to]		= 0
	self.loyalty[square_from]		= -1
	self.loyalty[square_to]			= self.color_to_move

	--switch turn
	self.color_to_move = 1-self.color_to_move
end

function MoveGenerator:unmake_move(move)
	local square_from,square_to = move[1],move[2]
	local flags = move[3]
	self.color_to_move = 1-self.color_to_move

	self.board[square_to]			= flags.undo_move[1]
	self.board[square_from]			= flags.undo_move[2]
	self.first_moves[square_from]	= flags.undo_move[3]
	self.first_moves[square_to]		= flags.undo_move[4]
	self.loyalty[square_from]		= flags.undo_move[5]
	self.loyalty[square_to]			= flags.undo_move[6]
	self.king[self.color_to_move]	= flags.undo_move[7]

	if flags.is_en_passant then
		self.board[flags.is_en_passant] = flags[8]
		self.loyalty[flags.is_en_passant] = flags[9]
	elseif flags.is_castle then
		local rook_from = flags.is_castle[1]
		local rook_to = flags.is_castle[2]
		self.board[rook_to] = flags[8][1]
		self.board[rook_from] = flags[8][2]
		self.first_moves[rook_from] = flags[8][3]
		self.first_moves[rook_to] = flags[8][4]
		self.loyalty[rook_from] = flags[8][5]
		self.loyalty[rook_to] = flags[8][6]
	end
end

local function check_promotion(square_to,color)
	return square_to >= 57-56*color and square_to <= 64-56*color
end

local PawnData = {
	[1] = {
		move_1 = {-8,-16},
		move = -8,
		move_cap = {-7,-9}
	},
	[0] = {
		move_1 = {8,16},
		move = 8,
		move_cap = {7,9}
	}
}
function MoveGenerator:pawn_move(square, color, is_first_move, moves)
	local move_data = MoveData[square]
	local dirs_cap = {}
	if color == 1 then
		dirs_cap[1] = 8
		dirs_cap[2] = 6
	else
		dirs_cap[1] = 5
		dirs_cap[2] = 7
	end

	--captures--
	for _,dir in ipairs(dirs_cap) do
		if move_data[dir] == 0 then goto continue end
		local square_to = square + DirectionOffsets[dir]
		local square_piece = self.board[square_to]
		self.attacks[color][square_to] = 1

		if square_piece ~= 0 and self.loyalty[square_to] ~= color then
			local is_promotion = check_promotion(square_to,color)
			if is_promotion then
				moves[#moves+1] = {square, square_to, {is_promotion = 6}}
				moves[#moves+1] = {square, square_to, {is_promotion = 4}}
				moves[#moves+1] = {square, square_to, {is_promotion = 3}}
				moves[#moves+1] = {square, square_to, {is_promotion = 2}}
			else
				moves[#moves+1] = {square, square_to, {}}
			end
		end
		::continue::
	end

	--check en passant
	if self.last_move_pawn and self.last_move_pawn[2] == 16 then
		self:check_en_passant(square, color, moves, move_data, dirs_cap)
	end

	--regular moves--
	if is_first_move == 1 then
		for _,dir in ipairs(PawnData[color].move_1) do
			local square_to = square + dir
			local square_piece = self.board[square_to]

			if square_piece == 0 then moves[#moves+1] = {square, square_to, {}}
			else
				--on move 1, if there is a piece in front of the pawn it can't skip
				--over it to move two squares. so we stop here.
				return
			end
		end
	else
		local square_to = square + PawnData[color].move
		local square_piece = self.board[square_to]
		if square_piece == 0 then
			local is_promotion = check_promotion(square_to,color)
			if is_promotion then
				moves[#moves+1] = {square, square_to, {is_promotion = 6}}
				moves[#moves+1] = {square, square_to, {is_promotion = 4}}
				moves[#moves+1] = {square, square_to, {is_promotion = 3}}
				moves[#moves+1] = {square, square_to, {is_promotion = 2}}
			else
				moves[#moves+1] = {square, square_to, {}}
			end
		end
	end
end

function MoveGenerator:check_en_passant(square, color, moves, move_data, dirs_cap)
	local left = square-1
	local right = square+1
	if move_data[dirs_cap[1]] == 0 then left = -1 end
	if move_data[dirs_cap[2]] == 0 then right = -1 end
	if left == -1 and right == -1 then return end

	local left_to, right_to
	if color == 1 then
		left_to = left-8
		right_to = right-8
	else
		left_to = left+8
		right_to = right+8
	end
	if left == self.last_move_pawn[1] then
		moves[#moves+1] = {square, left_to, {is_en_passant = left}}
	end
	if right == self.last_move_pawn[1] then
		moves[#moves+1] = {square, right_to, {is_en_passant = right}}
	end
end

function MoveGenerator:knight_move(square, color, moves)
	local move_data = KnightData[square]
	
	for _,square_to in ipairs(move_data) do
		local square_piece = self.board[square_to]
		self.attacks[color][square_to] = 1
		if square_piece == 0 or self.loyalty[square_to] ~= color then
			moves[#moves+1] = {square, square_to, {}}
		end
	end
end

function MoveGenerator:king_move(square, color, is_first_move, moves)
	local move_data = MoveData[square]
	local start_dir,end_dir = 1,8

	for dir=start_dir,end_dir do
		if move_data[dir] == 0 then goto continue end
		local square_to = square + DirectionOffsets[dir]
		local square_piece = self.board[square_to]
		self.attacks[color][square_to] = 1

		if square_piece == 0 or self.loyalty[square_to] ~= color then
			moves[#moves+1] = {square, square_to, {}}
		end

		::continue::
	end

	if is_first_move == 1 then self:check_castling(square, color, moves) end
end

function MoveGenerator:check_castling(square, color, moves)
	if self:is_in_check(color) then return end
	local rook_r,rook_l = 64,57
	if color == 0 then rook_r,rook_l = 8,1 end
	
	--check if rook's first move
	if self.first_moves[rook_r] == 1 and self.board[rook_r] == 4 then
		--check in-between squares are empty
		if self.board[square+1] == 0 and self.board[square+2] == 0 then
			--check attacking sightlines
			if not self:is_in_check(color,square+1) and not self:is_in_check(color,square+1) then
				moves[#moves+1] = {square, square+2, {is_castle = {rook_r,rook_r-2}}}
			end
		end
	end

	if self.first_moves[rook_l] == 1 and self.board[rook_l] == 4 then
		if self.board[square-1] == 0 and self.board[square-2] == 0 and self.board[square-3] == 0 then
			if not self:is_in_check(color,square-1) and not self:is_in_check(color,square-2) then
				moves[#moves+1] = {square, square-2, {is_castle = {rook_l,rook_l+3}}}
			end
		end
	end
end

function MoveGenerator:sliding_move(square, color, piece, moves)
	local move_data = MoveData[square]
	local start_dir,end_dir = 1,8 --queen
	if piece == 4 then end_dir = 4 end --rook
	if piece == 3 then start_dir = 5 end --bishop

	for dir=start_dir,end_dir do
		for i=1,move_data[dir] do
			local square_to = square + DirectionOffsets[dir] * i

			if not self.board[square_to] then --off the board
				dir = dir + 1 --skip to the next direction
				goto continue
			else
				if self.board[square_to] == 0 then --square is empty
					self.attacks[color][square_to] = 1
					moves[#moves+1] = {square, square_to, {}}
				else
					if self.loyalty[square_to] == color then --square contains allied piece
						self.attacks[color][square_to] = 1
						dir = dir + 1
						goto continue
					else
						--a piece can be captured, but no more
						--moves are possible in that direction
						self.attacks[color][square_to] = 1
						moves[#moves+1] = {square, square_to, {}}
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
end

function MoveGenerator:castle(rook_from, rook_to)
	self.board[rook_to]			= 4
	self.board[rook_from]		= 0
	self.first_moves[rook_from]	= 0
	self.first_moves[rook_to]	= 0
	self.loyalty[rook_from]		= -1
	self.loyalty[rook_to]		= self.color_to_move
end

----
local function convert(from, to)
	local movefrom = ''
	local moveto = ''

	for file,array in pairs(all_files) do
		if table_contains(array,from) then
			movefrom = movefrom..file
		end
		if table_contains(array,to) then
			moveto = moveto..file
		end
	end

	for rank,array in ipairs(ranks) do
		if from >= array[1] and from <= array[2] then
			movefrom = movefrom..rank
		end
		if to >= array[1] and to <= array[2] then
			moveto = moveto..rank
		end
	end
	return movefrom..moveto
end

function MoveGenerator:generation_test(depth)
	if depth == 0 then return 1 end
	local moves = self:generate_pseudo_legal_moves()
	local legal_moves = self:generate_legal_moves(moves)
	local num_positions = 0
	
	for _,move in ipairs(legal_moves) do
		self:make_move(move)
		local positions = self:generation_test(depth-1)
		num_positions = num_positions + positions
		self:unmake_move(move)
	end

	return num_positions
end

function MoveGenerator:contains_move(square_from, square_to)
	for i,move in ipairs(self.legal_moves) do
		if move[1] == square_from and move[2] == square_to then
			return move
		end
	end
	return nil
end

return MoveGenerator