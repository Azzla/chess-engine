local Bot = {}
local PieceMaps = require('dicts.piece_maps')
local pawn_v	= 100
local knight_v	= 320
local bishop_v	= 330
local rook_v	= 500
local king_v	= 10000
local queen_v	= 900
local value_map = {
	pawn_v,
	knight_v,
	bishop_v,
	rook_v,
	king_v,
	queen_v
}
local sort,floor,max,min,abs = table.sort,math.floor,math.max,math.min,math.abs

function Bot:init(MoveGenerator)
	self.MoveGenerator = MoveGenerator
	self.moves = {}
	self.principal_variation = {}
	self.root_depth = 4
end

--TODO: Hard coding search depth 4 so that I can store the
--correct best move for the root-node of the search tree.
local function negate(val1, val2)
	return -1*val1,val2
end

function Bot:search(depth, alpha, beta)
	if depth == 0 then return self:search_captures(alpha, beta) end
	local moves = self.MoveGenerator:generate_pseudo_legal_moves()
	local legal_moves = self.MoveGenerator:generate_legal_moves(moves)

	if #legal_moves == 0 then
		if self.MoveGenerator:is_in_check(self.MoveGenerator.color_to_move) then
			--found checkmate
			return -(50000+depth),0
		else
			--stalemate
			return 0,0
		end
	end

	self:order_moves(legal_moves)

	for i,move in ipairs(legal_moves) do
		self.MoveGenerator:make_move(move)
		local eval,num_moves = negate(self:search(depth-1, -beta, -alpha))
		self.MoveGenerator:unmake_move(move)
		
		if eval >= beta then return beta,0 end --byebye branch
		if eval > alpha then
			if not self:is_repetition(move) then
				alpha = eval

				if depth == self.root_depth then
					self.best_move = move
				end
			end
		end
	end
	
	return alpha,#legal_moves
end

function Bot:search_captures(alpha, beta)
	local eval = self:evaluate()
	if eval >= beta then return beta end
	alpha = math.max(alpha, eval)

	local moves = self.MoveGenerator:generate_pseudo_legal_moves()
	local legal_moves = self.MoveGenerator:generate_legal_moves(moves)
	local captures = self.MoveGenerator:generate_captures(legal_moves)
	
	self:order_moves(captures)
	
	for i,move in ipairs(captures) do
		self.MoveGenerator:make_move(move)
		eval,num_moves = -self:search_captures(-beta, -alpha)
		self.MoveGenerator:unmake_move(move)

		if eval >= beta then return beta,num_moves end
		if eval > alpha then
			alpha = eval
		end
	end
	
	return alpha,#legal_moves
end

function Bot:order_moves(moves)
	local board = self.MoveGenerator.board
	local move_scores = {}

	for i,move in ipairs(moves) do
		local move_score_guess = 0
		local moved_piece = board[move[1]]
		local captured_piece = board[move[2]]

		--the highest priority goes to the principal variation, or the best moves
		--from previous searches

		--prioritize capturing higher-value pieces with lower-value pieces
		if captured_piece ~= 0 then
			move_score_guess = 10 * value_map[captured_piece] - value_map[moved_piece]
		end

		--checks are probably good
		--TODO: fast check detect

		--promotion is probably good
		if move[3].is_promotion then
			move_score_guess = move_score_guess + value_map[move[3].is_promotion]
		end

		--penalize moving pieces to squares attacked by opponent's pawns
		--TODO: individual piece attack maps

		move_scores[i] = move_score_guess
		move[3].value = move_score_guess
	end
	
	local function value_sort(a,b)
		return a[3].value > b[3].value
	end
	sort(moves, value_sort)
end

function Bot:evaluate()
	local white_eval = self:count_material(1)
	local black_eval = self:count_material(0)
	local total_material = white_eval + black_eval

	local white_bonus = self:count_square_bonus(1, total_material)
	local black_bonus = self:count_square_bonus(0, total_material)
	local evaluation = (white_eval+white_bonus) - (black_eval+black_bonus)
	local perspective = (2*self.MoveGenerator.color_to_move)-1

	return perspective*evaluation,0
end

function Bot:count_material(color)
	local loyalty = self.MoveGenerator.loyalty
	local board = self.MoveGenerator.board
	local material = 0
	
	for i,loyalty in ipairs(loyalty) do
		local piece = board[i]
		if loyalty == color and piece ~= 0 then
			material = material + value_map[piece]
		end
	end

	return material
end

function Bot:count_square_bonus(color, material)
	local loyalty = self.MoveGenerator.loyalty
	local board = self.MoveGenerator.board
	local bonus = 0

	for i,loyalty in ipairs(loyalty) do
		local piece = board[i]
		if loyalty == color and piece == 5 then
			--if the amount of material on the board is slightly less than half,
			--ignoring pawns, we declare that its the endgame.
			local is_endgame = material-20000 <= 2000
			if is_endgame then
				bonus = bonus + PieceMaps[color][piece].endgame[i]
				--force enemy king to corner
				local enemy_king = self.MoveGenerator.king[1-color]
				local force_bonus = self:force_king_corner(i,enemy_king)
				bonus = bonus + force_bonus
			else
				bonus = bonus + PieceMaps[color][piece].midgame[i]
			end
		elseif loyalty == color and piece ~= 0 then
			bonus = bonus + PieceMaps[color][piece][i]
		end
	end

	return bonus
end

function Bot:force_king_corner(friendly_king, enemy_king)
	local endgame_weight = 10
	local eval = 0

	local enemy_king_rank = floor((enemy_king-1)/8)+1
	local enemy_king_file = ((enemy_king-1) % 8)+1
	local enemy_king_dist_center_file = max(3-enemy_king_file,enemy_king_file-4)
	local enemy_king_dist_center_rank = max(3-enemy_king_rank,enemy_king_rank-4)
	local enemy_king_dist_center = enemy_king_dist_center_file + enemy_king_dist_center_rank
	eval = eval + enemy_king_dist_center

	local friendly_king_rank = floor((friendly_king-1)/8)+1
	local friendly_king_file = ((friendly_king-1) % 8)+1
	local dist_king_files = abs(friendly_king_file-enemy_king_file)
	local dist_king_ranks = abs(friendly_king_rank-enemy_king_rank)
	local dist_between_kings = dist_king_files+dist_king_ranks
	eval = eval + 14 - dist_between_kings

	return eval * 10 * endgame_weight
end

function Bot:is_repetition(move)
	if #self.moves < 3 then return false end
	local prev_move   = self.moves[#self.moves]
	--local prev_move_2 = self.moves[#self.moves-1]
	--local prev_move_3 = self.moves[#self.moves-2]

	return move[2] == prev_move[1]
end

return Bot