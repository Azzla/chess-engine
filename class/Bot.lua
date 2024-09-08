local Bot = {}

local pawn_v	= 100
local knight_v	= 300
local bishop_v	= 320
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

function Bot:init(MoveGenerator)
	self.MoveGenerator = MoveGenerator
end

--TODO: Hard coding search depth so that I can store the
--correct best move for the root-node of the search tree.
function Bot:search(depth, alpha, beta)
	if depth == 0 then return self:search_captures(alpha, beta) end
	local moves = self.MoveGenerator:generate_pseudo_legal_moves()
	local legal_moves = self.MoveGenerator:generate_legal_moves(moves)

	if #legal_moves == 0 then
		if self.MoveGenerator:is_in_check(self.MoveGenerator.color_to_move) then
			--checkmate
			return -10000
		else
			--stalemate
			return 0
		end
	end

	self:order_moves(legal_moves)

	for i,move in ipairs(legal_moves) do
		self.MoveGenerator:make_move(move)
		local eval = -self:search(depth-1, -beta, -alpha)
		self.MoveGenerator:unmake_move(move)

		if eval >= beta then return beta end --byebye branch
		if eval > alpha then
			alpha = eval
			if depth == 5 then self.best_move = move end
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
		eval = -self:search_captures(-beta, -alpha)
		self.MoveGenerator:unmake_move(move)

		if eval >= beta then return beta end
		if eval > alpha then
			alpha = eval
		end
	end
	
	return alpha
end

function Bot:order_moves(moves)
	local board = self.MoveGenerator.board
	local move_scores = {}

	for i,move in ipairs(moves) do
		local move_score_guess = 0
		local moved_piece = board[move[1]]
		local captured_piece = board[move[2]]

		--prioritize capturing higher-value pieces with lower-value pieces
		if captured_piece ~= 0 then
			move_score_guess = 10 * value_map[captured_piece] - value_map[moved_piece]
		end

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
	table.sort(moves, value_sort)
end

function Bot:evaluate()
	local white_eval = self:count_material(1)
	local black_eval = self:count_material(0)
	local evaluation = white_eval - black_eval
	local perspective = (2*self.MoveGenerator.color_to_move)-1

	return perspective * evaluation
end

function Bot:count_material(color)
	local loyalty = self.MoveGenerator.loyalty
	local board = self.MoveGenerator.board
	local material = 0
	
	for i,loyalty in ipairs(loyalty) do
		if loyalty == color and board[i] ~= 0 then
			material = material + value_map[board[i]]
		end
	end

	return material
end

return Bot