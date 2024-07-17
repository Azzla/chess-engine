local Test = {}

function Test:init(position)
	self.position = position
	self.total_moves = 0
end

function Test:run(depth, board)
	for i,ps in ipairs(board.board_pieces) do
		if ps == 0 then goto continue end
		board:select_piece(-1,-1,i)
		for j,v in ipairs(board.board_highlight) do
			if v == 1 or v == 2 then
				board:move_piece(-1,-1,j)
				board.board_highlight[j] = 0
				board:move_piece(-1,-1,i)
				self.total_moves=self.total_moves+1
			end
		end
		::continue::
	end
end

function Test:report()

end

return Test