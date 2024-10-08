local Game = {}
local Board = nil

function Game:enter(previous)
	Board = require('func.Board')
	self.scale = Options.h/4320
	self.next = 0
	self.ui = SUIT.new()
	Board:init(self.scale, Positions[1].FEN) --Default Position
	--Board:init(self.scale, Positions[4].FEN) --Easy Win Position
	--Board:init(self.scale, Positions[2].FEN) --Castling Test
	--Board:init(self.scale, Positions[3].FEN) --Checkmate Test
	--Board:init(self.scale, '1qk5/8/8/8/8/3K4/8/8') --Endgame Test
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

	if Board.stalemate then
		love.graphics.setColor(1,1,1,1)
		love.graphics.setFont(Font_64)
		love.graphics.printf("Draw by Stalemate", 0, 5, Options.w, 'center')
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
		local btn_w = 150
		local btn_h = 50
		self.ui.layout:reset(Options.w-btn_w,Options.h-btn_h)
		if self.ui:Button("reset", {font=Font_32}, self.ui.layout:row(btn_w, btn_h)).hit then
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
end

function Game:resize(w,h)
	Options.h = h; Options.w = h*1.4;
	love.window.setMode(Options.w,Options.h,Options.flags)
	self.scale = h/4320

	Board.scale = h/4320
	Board.screen_offset_x = (Options.w - (Board.tile_w*Board.squares*Board.scale))/2
	Board.screen_offset_y = (Options.h - (Board.tile_w*Board.squares*Board.scale))/2
end

return Game