local PieceData = require('dicts.piece_data')
local MoveData,DirectionOffsets = require('dicts.move_data')()
local Move = require('class.Move')
local MoveGenerator = {}

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
	self.king				= {[0]=5,[1]=61}
	self.pseudo_legal_moves	= {}
	self.legal_moves		= {}
	self.attacks			= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}
	self.move_log			= move_log or {}
	self.last_move_pawn		= nil
	self.color_to_move		= 1
end

function MoveGenerator:generate_pseudo_legal_moves()
	local moves = {}
	local color = self.color_to_move
	self.attacks[color] = table_shallow_copy(blank_board)


	for square,piece in ipairs(self.board) do
		if self.loyalty[square] ~= color then goto continue end

		if piece == 1 then
			self:pawn_move(square, color, self.first_moves[square], moves)
		end
		if piece == 2 then
			self:knight_move(square, color, moves)
		end
		if piece == 5 then
			self:king_move(square, color, self.first_moves[square], moves)
		end
		if piece == 3 or piece == 4 or piece == 6 then
			self:sliding_move(square, color, piece, moves)
		end

		::continue::
	end

	return moves
end

function MoveGenerator:generate_legal_moves(moves)
	local legal_moves = self:filter_illegal_moves(moves)
	if #legal_moves == 0 then self.checkmate = true end
	self.legal_moves = legal_moves
	return legal_moves
end

function MoveGenerator:filter_illegal_moves(moves)
	local king_color = self.color_to_move
	local new_moves = {}

	for i,move in ipairs(moves) do
		self:make_move(move)
		local responses = self:generate_pseudo_legal_moves()
		for _,response in ipairs(responses) do
			if response[3].is_capture and self.board[response[2]] == 5 then
				self:unmake_move(move)
				goto continue
			end
		end
		table.insert(new_moves, move)
		self:unmake_move(move)
		::continue::
	end
	return new_moves
end

function MoveGenerator:make_move(move)
	local square_from,square_to = move[1],move[2]
	local flags = move[3]
	
	--record the board state before this move was made
	move[3].last_board_state = {
		table_shallow_copy(self.board),
		table_shallow_copy(self.first_moves),
		table_shallow_copy(self.loyalty),
		table_shallow_copy(self.king)
	}
	
	-----
	--if it's a pawn, check for passant, promotion, and record the move
	if self.board[square_from] == 1 then
		self.last_move_pawn = {square_to, math.abs(square_to-square_from)}
		self:check_promotion(square_to)
		if flags.is_en_passant then
			self.board[flags.is_en_passant] = 0
			self.loyalty[flags.is_en_passant] = -1
		end
	else
		self.last_move_pawn = nil
	end
	-----
	--if it's a king, check for castling and record the king's new position
	if self.board[square_from] == 5 then
		if flags.is_castle then
			local rook_from = flags.is_castle[1]
			local rook_to = flags.is_castle[2]
			self.board[rook_to]			= 4
			self.board[rook_from]		= 0
			self.first_moves[rook_from]	= 0
			self.first_moves[rook_to]	= 0
			self.loyalty[rook_from]		= -1
			self.loyalty[rook_to]		= self.color_to_move
		end

		self.king[self.color_to_move] = square_to
	end

	--reflect the move on the board state
	self.board[square_to]			= self.board[square_from]
	self.board[square_from]			= 0
	self.first_moves[square_from]	= 0
	self.first_moves[square_to]		= 0
	self.loyalty[square_from]		= -1
	self.loyalty[square_to]			= self.color_to_move

	--switch turn
	self.color_to_move = 1-self.color_to_move
end

function MoveGenerator:unmake_move(move)
	self.color_to_move = 1-self.color_to_move

	self._board.board_pieces = table_shallow_copy(move[3].last_board_state[1])
	self._board.board_first_move = table_shallow_copy(move[3].last_board_state[2])
	self._board.board_loyalty = table_shallow_copy(move[3].last_board_state[3])

	self.king =  table_shallow_copy(move[3].last_board_state[4])
	self.board = self._board.board_pieces
	self.first_moves = self._board.board_first_move
	self.loyalty = self._board.board_loyalty
end

-----------
--these are used to filter out invalid board-wrapping moves--
local a_file = {1,9,17,25,33,41,49,57}
local ab_file = {1,9,17,25,33,41,49,57,2,10,18,26,34,42,50,58}
local gh_file = {7,15,23,31,39,47,55,63,8,16,24,32,40,48,56,64}
local h_file = {8,16,24,32,40,48,56,64}

function MoveGenerator:is_in_check(color)
	for i,attacks in ipairs(self.attacks[1-color]) do
		if i == self.king[color] and attacks == 1 then
			return true
		end
	end
	return false
end

function MoveGenerator:pawn_move(square, color, is_first_move, moves)
	local Data = PieceData[1]
	--captures--
	local dirs_cap = Data[color].move_cap
	for _,dir in ipairs(dirs_cap) do
		local square_to = square + dir
		local square_piece = self.board[square_to]
		
		--add to attack table
		if not self:check_board_wrap(square, square_to) then
			self.attacks[color][square_to] = 1
		end

		if square_piece ~= 0
		and self.loyalty[square_to] ~= color
		and not self:check_board_wrap(square, square_to) then
			table.insert(moves, Move.new(square, square_to, {is_capture = true}))
		end
	end

	--regular moves--
	local dirs
	if is_first_move == 1 then dirs = Data[color].move_1
	else dirs = Data[color].move end
	for _,dir in ipairs(dirs) do
		local square_to = square + dir
		local square_piece = self.board[square_to]
		if square_piece == 0 then
			--square is empty
			table.insert(moves, Move.new(square, square_to))
		else
			--on move 1, if there is a piece in front of the pawn it can't skip
			--over it to move two squares. so we stop here.
			return
		end
	end

	--check en passant
	self:check_en_passant(square, color, moves)
end

function MoveGenerator:check_en_passant(square, color, moves)
	local left = square-1
	local right = square+1
	local left_to, right_to
	if color == 1 then
		left_to = left-8
		right_to = right-8
	else
		left_to = left+8
		right_to = right+8
	end
	if self.last_move_pawn and self.last_move_pawn[2] == 16 then
		if left == self.last_move_pawn[1] and not self:check_board_wrap(square, left_to)
		then
			table.insert(moves, Move.new(square, left_to, {
				is_capture = true,
				is_en_passant = left
			}
			))
		end
		if right == self.last_move_pawn[1] and not self:check_board_wrap(square, right_to)
		then
			table.insert(moves, Move.new(square, right_to, {
				is_capture = true,
				is_en_passant = right
			}
			))
		end
	end
end

function MoveGenerator:knight_move(square, color, moves)
	for _,dir in ipairs(PieceData[2].move) do
		local square_to = square + dir
		local square_piece = self.board[square_to]
		
		--add to attack table
		if not self:check_board_wrap_knight(square, square_to) then
			self.attacks[color][square_to] = 1
		end

		if square_piece and not self:check_board_wrap_knight(square, square_to) then
			if square_piece == 0 then
				table.insert(moves, Move.new(square, square_to))
			elseif self.loyalty[square_to] ~= color then
				table.insert(moves, Move.new(square, square_to, {is_capture = true}))
			end
		end
	end
end

function MoveGenerator:king_move(square, color, is_first_move, moves)
	for _,dir in ipairs(PieceData[5].move) do
		local square_to = square + dir
		local square_piece = self.board[square_to]

		--add to attack table
		if not self:check_board_wrap(square, square_to) then
			self.attacks[color][square_to] = 1
		end

		if square_piece and not self:check_board_wrap(square, square_to) then
			if square_piece == 0 then
				table.insert(moves, Move.new(square, square_to))
			elseif self.loyalty[square_to] ~= color then
				table.insert(moves, Move.new(square, square_to, {is_capture = true}))
			end
		end
	end

	if is_first_move then self:check_castling(square, color, moves) end
end

function MoveGenerator:check_castling(square, color, moves)
	if self:is_in_check(color) then return end
	local rook_r,rook_l = 64,57
	if color == 0 then rook_r,rook_l = 8,1 end

	--check if rook's first move
	if self.first_moves[rook_r] then
		--check in-between squares are empty
		if self.board[square+1] == 0 and self.board[square+2] == 0 then
			--check attacking sightlines
			if self.attacks[1-color][square+1] == 0 and self.attacks[1-color][square+2] == 0 then
				table.insert(moves, Move.new(square, square+2, {is_castle = {rook_r,rook_r-2}}))
			end
		end
	end

	if self.first_moves[rook_l] then
		if self.board[square-1] == 0 and self.board[square-2] and self.board[square-3] == 0 then
			if self.attacks[1-color][square-1] == 0 and self.attacks[1-color][square-2] and self.attacks[1-color][square-3] == 0 
			then
				table.insert(moves, Move.new(square, square-2, {is_castle = {rook_l,rook_l+3}}))
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
					table.insert(moves, Move.new(square, square_to))
				else
					if self.loyalty[square_to] == color then --square contains allied piece
						self.attacks[color][square_to] = 1
						dir = dir + 1
						goto continue
					else
						--a piece can be captured, but no more
						--moves are possible in that direction
						self.attacks[color][square_to] = 1

						table.insert(
							moves,
							Move.new(square, square_to, {is_capture = true})
						)
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
end

function MoveGenerator:check_board_wrap(pawn_i,target_i)
	if table_contains(a_file, pawn_i) then
		if table_contains(h_file, target_i) then return true end
	elseif table_contains(h_file, pawn_i) then
		if table_contains(a_file, target_i) then return true end
	end
	return false
end

function MoveGenerator:check_board_wrap_knight(knight_i, target_i)
	if table_contains(ab_file, knight_i) then
		if table_contains(gh_file, target_i) then return true end
	elseif table_contains(gh_file, knight_i) then
		if table_contains(ab_file, target_i) then return true end
	end
	return false
end

function MoveGenerator:check_promotion(square_to)
	local color = self._board.color_to_move
	if color == 1 and square_to >= 1 and square_to <= 8 then
		return true
	end
	if color == 0 and square_to >= 57 and square_to <= 64 then
		return true
	end
	return false
end

function MoveGenerator:promote(index, color, to_piece_id)
	self.promoting = false
	self.ui = SUIT.new()
	SFX.promote:play()

	local piece = Unit(
		to_piece_id,
		index-1,
		color,
		self.tile_w,
		self.screen_offset_x,
		self.screen_offset_y,
		self.scale
	)
	self.board_pieces[index] = piece
	self:check_checkmate(piece)
	Evaluation:eval(self.board_pieces)
end

----
function MoveGenerator:generation_test(depth)
	if depth == 0 then return 1 end
	local moves = self:generate_pseudo_legal_moves()
	local legal_moves = self:generate_legal_moves(moves)
	local num_positions = 0
	
	for _,move in ipairs(legal_moves) do
		self:make_move(move)
		--table.insert(self.move_log, move)
		num_positions = num_positions + self:generation_test(depth-1)
		self:unmake_move(move)
		--table.insert(self.move_log, {move,true})
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