return [[
	local Bot = require('class.Bot')
	local MoveGenerator = require('func.MoveGenerator')
	MoveGenerator:thread_init()
	Bot:init(MoveGenerator)

	while true do
		local searching = love.thread.getChannel('search'):pop()
		local reset = love.thread.getChannel('reset'):pop()
		if searching then
			searching = false
			Bot.best_move = {1,1,{}}
			MoveGenerator:thread_supply(unpack(love.thread.getChannel('board'):pop()))
			


			local eval,num_moves = Bot:search(4, -math.huge, math.huge)
			--TODO Iterative Deepening + Principal Variation

			
			if not num_moves then
				if eval == 0 then
					love.thread.getChannel('stale'):push(true)
				else
					love.thread.getChannel('mate'):push(true)
				end
			else
				love.thread.getChannel('eval'):push(eval)
				love.thread.getChannel('move'):push(Bot.best_move)
				table.insert(Bot.moves,Bot.best_move)
			end
		end

		if reset then MoveGenerator:thread_init() end
	end
]]