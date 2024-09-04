local Game = {}
local Board = nil

function Game:enter(previous)
	Board = require('func.Board')
	self.scale = 0.25
	self.next = 0
	self.ui = SUIT.new()
	Board:init(self.scale, Positions[1].FEN) --Default Position
	--Board:init(self.scale, Positions[2].FEN) --Castling Test
	--Board:init(self.scale, Positions[3].FEN) --Checkmate Test
	--Board:init(self.scale, 'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R', 1) --Position 5
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
	if love.keyboard.isDown('right') then
		if self.next > 0.04 then
			self.next = 0
			Board:step()
		else
			self.next = self.next + dt
		end
	else
		self.next = 0
	end
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
		Board:mousereleased(x, y)
	end
end

function Game:keypressed(key)
	if key == '1' then Board:test(1) end
	if key == '2' then Board:test(2) end
	if key == '3' then Board:test(3) end
	if key == '4' then Board:test(4) end
	if key == '5' then Board:test(5) end
	if key == '6' then Board:test(6) end
	if key == 'right' then Board:step() end
	if key == 'space' then
		for i=1,26000 do Board:step() end
	end
end

return Game