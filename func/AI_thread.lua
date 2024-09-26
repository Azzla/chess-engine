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
			MoveGenerator:thread_supply(unpack(love.thread.getChannel('board'):pop()))
			
			local depth = 1
			local eval,num_moves = 0,0
			repeat
				Bot.root_depth = depth
				eval,num_moves = Bot:search(depth, -math.huge, math.huge, Bot.best_move)
				print('finished searching')
				depth = depth + 1
			until love.thread.getChannel('timeout'):pop()

			if not num_moves then
				if eval == 0 then
					love.thread.getChannel('stale'):push(true)
				else
					love.thread.getChannel('mate'):push(true)
				end
			else
				print('depth reached: ', depth)
				love.thread.getChannel('move'):push({eval, Bot.best_move})
				table.insert(Bot.moves,Bot.best_move)
			end
		end

		if reset then MoveGenerator:thread_init() end
	end
]]