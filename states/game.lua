local Game = {}
local Board = nil

function Game:enter(previous)
	Board = require('func.Board')
	self.scale = 0.25

	Board:init(self.scale, Positions[1].FEN) --Default Position
	--Board:init(self.scale, Positions[2].FEN) --Castling Test
end

function Game:draw()
	love.graphics.setColor(Colors.dark_gray)
	love.graphics.rectangle('fill',0,0,Options.w,Options.h)

	love.graphics.setColor(1,1,1,1)
	Board:draw_background()
	Board:draw()
	if Board.checkmate == 1 then
		love.graphics.setColor(1,1,1,1)
		love.graphics.setFont(Font_64)
		love.graphics.printf("Black Wins", 0, 10, Options.w)
	elseif Board.checkmate == 0 then
		love.graphics.setColor(1,1,1,1)
		love.graphics.setFont(Font_64)
		love.graphics.printf("White Wins", 0, 10, Options.w)
	end
end

function Game:mousepressed(x, y, btn)
	if btn == 1 then
		Board:select_piece(x, y)
	end
end

function Game:mousereleased(x, y, btn)
	if btn == 1 then
		Board:move_piece(x, y)
	end
end

return Game