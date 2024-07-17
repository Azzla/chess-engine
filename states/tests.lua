local Board = require('func.Board')
local Test = require('func.test')
local Positions = require('dicts.positions')

local Tests = {}

function Tests:enter(previous)
	self.scale = .25
	self.ply = 2
	Board:init(self.scale, Positions[1].FEN)
	Test:init(Positions[1].FEN)
	--Test:run(self.ply, Board)
end

function Tests:draw()
	love.graphics.setColor(.2,.25,.2,1)
	love.graphics.rectangle('fill',0,0,Options.w,Options.h)

	love.graphics.setColor(1,1,1,1)
	Board:draw_background()
	Board:draw()
end

return Tests