local Game = {}
local Board = nil

function Game:enter(previous)
	Board = require('func.Board')
	self.scale = 0.25
	self.ui = SUIT.new()
	--Board:init(self.scale, Positions[1].FEN) --Default Position
	Board:init(self.scale, Positions[2].FEN) --Castling Test
	--Board:init(self.scale, Positions[3].FEN) --Checkmate Test
end

function Game:draw()
	love.graphics.setColor(.2,.25,.2,1)
	love.graphics.rectangle('fill',0,0,Options.w,Options.h)

	love.graphics.setColor(1,1,1,1)
	Board:draw_background()
	Board:draw()
	if Board.checkmate == 1 then
		love.graphics.setColor(1,1,1,1)
		love.graphics.setFont(Font_64)
		love.graphics.printf("Black Wins", 0, 5, Options.w, 'center')
	elseif Board.checkmate == 0 then
		love.graphics.setColor(1,1,1,1)
		love.graphics.setFont(Font_64)
		love.graphics.printf("White Wins", 0, 5, Options.w, 'center')
	end

	if Board.check ~= -1 then
		self.ui:draw()
	end
end

function Game:update(dt)
	Board:update(dt)

	if Board.checkmate ~= -1 then
		local btn_w = 300
		self.ui.layout:reset(Options.w/2-btn_w/2,Options.h-80)
		if self.ui:Button("reset", self.ui.layout:row(btn_w, 80)).hit then
			Board:reset(Positions[1].FEN)
		end
	else
		if Options.allow_undo then
			local btn_w = 300
			self.ui.layout:reset(Options.w/2-btn_w/2,Options.h-80)
			if self.ui:Button("undo", self.ui.layout:row(btn_w, 80)).hit then
				Board:undo_move()
			end	
		end
	end
end

function Game:mousepressed(x, y, btn)
	if Board.promoting then return end
	if btn == 1 then
		Board:select_piece(x, y)
	end
end

function Game:mousereleased(x, y, btn)
	if Board.promoting then return end
	if btn == 1 then
		Board:move_piece(x, y)
	end
end

return Game