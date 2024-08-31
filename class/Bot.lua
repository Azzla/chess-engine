local Bot = {}

function Bot:make_random(board)
	--exit if checkmate
	if board.checkmate ~= -1 then return end

	local possible_pieces = {}
	for i,piece in ipairs(board.board_pieces) do
		if piece ~= 0
		and piece.color == 0 then
			table.insert(possible_pieces, {i, piece})
		end
	end
	local rand_i = love.math.random(1, #possible_pieces)
	local rand_piece = possible_pieces[rand_i]

	board:select_piece(-1,-1,rand_piece[1])
	
	local possible_squares = {}
	for i,square in ipairs(board.board_highlight) do
		if square == 1 or square == 2 then
			table.insert(possible_squares, i)
		end
	end
	local rand_i_2 = love.math.random(1, #possible_squares)
	local rand_move = possible_squares[rand_i_2]

	board:move_piece(-1,-1,rand_move)
end

return Bot