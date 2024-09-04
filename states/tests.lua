local Board = require('func.Board')
local Positions = require('dicts.positions')

local Tests = {}

function Tests:enter(previous)
	self.scale = .25
	self.ply = 2
	Board:init(self.scale, Positions[1].FEN)
end

function Tests:draw()
	love.graphics.setColor(.2,.25,.2,1)
	love.graphics.rectangle('fill',0,0,Options.w,Options.h)

	love.graphics.setColor(1,1,1,1)
	Board:draw_background()
	Board:draw()
end

function Tests:update(dt)
	Timer:update(dt)
end

function Tests:test_suite(ply)
	io.input("dicts/perftsuite.txt")
	local smallest_num = 9999999999999999999
	local small_fen = nil
	while true do
		local line = io.read()
		if line == nil then break end
		---~~~---
		local tokens = {}
		for token in line:gmatch('%S+') do
			table.insert(tokens,token)
		end
		local FEN = tokens[1]
		local to_move
		if tokens[2] == 'w' then to_move = 1 else to_move = 0 end
		local d1_i = 8
		
		Board:reset(FEN,to_move)
		print('')
		print('Position: '..FEN)
		print(tokens[2]..' to move')
		for i=1,ply do
			local num = Board:test(i)
			print(
				'Depth: '..tostring(i),
				'Expected: '..tokens[d1_i+(2*(i-1))],
				'Actual: '..tostring(num)
			)
			if tonumber(tokens[d1_i+(2*(i-1))]) ~= num and num < smallest_num then
				smallest_num = num
				small_fen = FEN
			end
		end
	end
	print(small_fen)
end

function Tests:keypressed(key)
	if key == '1' then self:test_suite(1) end
	if key == '2' then self:test_suite(2) end
	if key == '3' then self:test_suite(3) end
	if key == '4' then self:test_suite(4) end
	if key == '5' then self:test_suite(5) end
end

return Tests