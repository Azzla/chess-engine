local Game = {}
local Board = nil

function Game:enter(previous)
	Board = require('func.Board')

	self.ui = SUIT.new()
	self.level = Levels[1]
	self.scale = 0.25
	Board:init(self.scale, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR") --Default Position
end

function Game:update(dt)
	--UI--
	self.ui.layout:reset(0,0)
end

function Game:draw()
	love.graphics.setColor(love.math.colorFromBytes(124,76,62,255))
	love.graphics.rectangle('fill',0,0,Options.w,Options.h)
	love.graphics.setColor(1,1,1,1)
	
	love.graphics.printf(self.level.name, 0, 30, Options.w, "center")
	Board:draw_background(self.scale)
	Board:draw()
	self.ui:draw()
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