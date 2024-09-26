local Board = {}
local MoveGenerator = require('func.MoveGenerator')
local PieceData = require('dicts.piece_data')
--local Bot = require('class.Bot')
local FENParser = require('func.FENParser')
local Evaluation = require('func.eval')
local AI_THREAD
local threadCode = require('func.AI_thread')

local function to_xy_coordinates(index)
	local grid_size = 8

	local x = index % grid_size + 1
	local y = math.floor(index / grid_size) + 1

	return x,y
end

local function xy_to_index(x,y)
	local grid_size = 8
	return (grid_size * (y-1)) + x
end

-- 1 = white; 0 = black;
local board_background = {
	1,0,1,0,1,0,1,0,
	0,1,0,1,0,1,0,1,
	1,0,1,0,1,0,1,0,
	0,1,0,1,0,1,0,1,
	1,0,1,0,1,0,1,0,
	0,1,0,1,0,1,0,1,
	1,0,1,0,1,0,1,0,
	0,1,0,1,0,1,0,1
}
local blank_board = {
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0		
}

function Board:init(scale, _fen, color)
	self._fen_init = _fen
	self.step_i = 1
	self.scale = scale or 1
	self.squares = 8
	self.tile_w = 450
	self.anim_timer = Timer.new()
	self.animate = {x=0,y=0}
	self.tween = Tween.new(1,{},{})
	self.screen_offset_x = (Options.w - (self.tile_w*self.squares*self.scale))/2
	self.screen_offset_y = (Options.h - (self.tile_w*self.squares*self.scale))/2
	self.ui = SUIT.new()
	self.light_color = {love.math.colorFromBytes(235,236,208,255)}
	self.dark_color = {love.math.colorFromBytes(115,149,82,255)}
	self.move_high = {love.math.colorFromBytes(235,97,80,204)}
	self.last_move_high = {love.math.colorFromBytes(255,255,51,127)}

	-- 1 = white; 0 = black; -1 = none;
	self.board_loyalty = table_add(table_shallow_copy(blank_board), -1)

	-- 0 = normal; 1 = moveable highlight; 2 = capturable highlight; 3 = last-move highlight;
	self.board_highlight = table_shallow_copy(blank_board)
	self.captured = {
		[0] = {},
		[1] = {}
	}
	self.board_attacks		= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}

	-- 0 = none; 1 = pawn; 2 = knight; 3 = bishop; 4 = rook; 5 = king; 6 = queen;
	self.board_pieces = table_shallow_copy(blank_board)
	self.king = {}
	-- 0 = not first move; 1 = first move
	self.board_first_move	= table_shallow_copy(blank_board)

	self.color_to_move		= color or 1 --1 = white; 0 = black;
	self.selected_piece		= nil --the square that the piece is on
	self.promoting			= false
	self.w_time				= 600 --10 minutes in seconds
	self.b_time				= 600 --10 minutes in seconds
	self.run_test			= nil
	self.searching			= false
	self.search_limit		= .05 -- 50 ms search limit + exceeded
	self.search_time		= 0
	self.message_sent		= false

	FENParser.parse(_fen, self)
	MoveGenerator:init(self)
	local moves = MoveGenerator:generate_pseudo_legal_moves()
	MoveGenerator.legal_moves = MoveGenerator:generate_legal_moves(moves)
	self.board_attacks[1] = table_shallow_copy(MoveGenerator.attacks[self.color_to_move])
	
	if Options.ai_black then
		AI_THREAD = love.thread.newThread(threadCode)
		AI_THREAD:start()
	end
end

function Board:reset(_fen, to_move)
	self.board_loyalty		= table_add(table_shallow_copy(blank_board), -1)
	self.board_highlight	= table_shallow_copy(blank_board)
	self.captured = {
		[0] = {},
		[1] = {}
	}
	self.board_attacks		= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}
	self.board_pieces		= table_shallow_copy(blank_board)
	self.board_first_move	= table_shallow_copy(blank_board)
	self.color_to_move		= to_move or 1
	self.selected_piece		= nil
	self.promoting			= false
	self.w_time				= 600
	self.b_time				= 600
	self.run_test			= nil
	self.searching			= false
	self.checkmate			= nil
	self.stalemate			= nil

	FENParser.parse(_fen, self)
	MoveGenerator:init(self)

	local moves = MoveGenerator:generate_pseudo_legal_moves()
	MoveGenerator.legal_moves = MoveGenerator:generate_legal_moves(moves)
	self.board_attacks[1] = table_shallow_copy(MoveGenerator.attacks[self.color_to_move])

	--reset threaded AI
	if Options.ai_black then
		love.thread.getChannel('reset'):push(true)
	end
end

function Board:update(dt)
	self.anim_timer:update(dt)
	self.tween:update(dt)
	self:update_timers(dt)

	if Options.ai_black and self.searching then
		self.search_time = self.search_time + dt
		if self.search_time >= self.search_limit and not self.message_sent then
			love.thread.getChannel('timeout'):push(true)
			self.message_sent = true
		end

		local move_received = love.thread.getChannel('move'):pop()
		local mate_received = love.thread.getChannel('mate'):pop()
		local stale_received = love.thread.getChannel('stale'):pop()
		if mate_received then
			self.checkmate = self.color_to_move
			self.searching = false
			SFX.checkmate:play()
		elseif stale_received then
			self.stalemate = true
			self.searching = false
			SFX.checkmate:play()
		elseif move_received then
			print('received')
			print(move_received[2][1],move_received[2][2])
			self:animate_move(move_received[2])
			self.anim_timer:after(.3, function()
				self.animated_piece = nil
				self:ai_callback(move_received[2])
			end)
		end
	end
end

function Board:update_timers(dt)
	if not MoveGenerator.made_first_move then return end
	if self.checkmate then return end
	if self.color_to_move == 1 then self.w_time = self.w_time - dt end
	if self.color_to_move == 0 then self.b_time = self.b_time - dt end
	if self.w_time <= 0 then
		SFX.checkmate:play()
		self.checkmate = 1
		self.w_time = 0
	end
	if self.b_time <= 0 then
		SFX.checkmate:play()
		self.checkmate = 0
		self.b_time = 0
	end
end

function Board:animate_move(move)
	local x,y = to_xy_coordinates(move[1]-1)
	local x2,y2 = to_xy_coordinates(move[2]-1)
	self.animate = {x=x,y=y}
	self.animated_piece = move[1]
	self.tween = Tween.new(0.3,self.animate,{x=x2,y=y2},"inOutCubic")
end

function Board:draw_piece(piece, square, color)
	local piece_data = PieceData[piece]
	local scale = self.scale * 3
	local x,y = to_xy_coordinates(square-1)
	local px = (x-1) * self.tile_w * self.scale + (self.screen_offset_x)
	local py = (y-1) * self.tile_w * self.scale + (self.screen_offset_y)

	local asset_color
	if color == 1 then asset_color = 'w' else asset_color = 'b' end

	if self.animated_piece and self.animated_piece == square then
		px = (self.animate.x-1) * self.tile_w * self.scale + (self.screen_offset_x)
		py = (self.animate.y-1) * self.tile_w * self.scale + (self.screen_offset_y)
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(
			Assets[asset_color][piece_data.name],
			px,py,
			0,
			scale,scale
		)
	elseif self.selected_piece == square then
		x,y = love.mouse.getPosition()
		love.graphics.setColor(.5,1,.5,1)
		love.graphics.draw(
			Assets[asset_color][piece_data.name],
			x,y,
			0,
			scale,scale,
			piece_data.dimensions[1]/2,
			piece_data.dimensions[2]/2
		)
	else
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(
			Assets[asset_color][piece_data.name],
			px,py,
			0,
			scale,scale
		)
	end
end

function Board:draw()
	self:draw_timers()
	self:draw_captured()
	for i,piece in ipairs(self.board_pieces) do
		if piece ~= 0 then
			self:draw_piece(piece, i, self.board_loyalty[i], false)
		end
	end
	if self.promoting then
		self.ui:draw()
		self:draw_promotion_buttons(self.promoting.asset_color)
	end
end



function Board:promotion()
	if not self.promoting then return end
	print('made it')
	local btn_w = self.tile_w*self.scale
	local x,y = to_xy_coordinates(self.promoting.index)
	local index = self.promoting.index
	local loyalty = self.promoting.color
	--Auto-Queen Options--
	if Options.auto_queen or loyalty == 0 then
		print('auto promote')
		MoveGenerator:promote(index, loyalty, 6)
		return
	end

	local color = self.promoting.asset_color
	if loyalty == 0 then y=y-btn_w*3 end

	self.ui.layout:reset(x-btn_w,y)
	local queen_btn = self.ui:Button("", {id=6}, self.ui.layout:row(btn_w,btn_w))
	local rook_btn = self.ui:Button("", {id=4}, self.ui.layout:row())
	local bishop_btn = self.ui:Button("", {id=3}, self.ui.layout:row())
	local knight_btn = self.ui:Button("", {id=2}, self.ui.layout:row())

	if queen_btn.hit then MoveGenerator:promote(index, loyalty, queen_btn.id) end
	if rook_btn.hit then MoveGenerator:promote(index, loyalty, rook_btn.id) end
	if bishop_btn.hit then MoveGenerator:promote(index, loyalty, bishop_btn.id) end
	if knight_btn.hit then MoveGenerator:promote(index, loyalty, knight_btn.id) end
end

function Board:draw_captured()
	local white = self.captured[1]
	local black = self.captured[0]
	local wy,by = 0,0
	local wx,bx = 0,0

	for i,piece in ipairs(white) do
		if i > 8 then wy,wx = 30,8 end
		local piece_data = PieceData[piece]
		love.graphics.draw(
			Assets['w'][piece_data.name],
			10+((i-wx)*25),180+wy,
			0,
			.25,.25
		)
	end

	for i,piece in ipairs(black) do
		if i > 8 then by,bx = -30,8 end
		local piece_data = PieceData[piece]
		love.graphics.draw(
			Assets['b'][piece_data.name],
			10+((i-bx)*25),Options.h-210+by,
			0,
			.25,.25
		)
	end
end

function Board:draw_promotion_buttons(color)
	local x,y = self.ui.layout._x+10, self.ui.layout._y+10
	love.graphics.draw(
		Assets[color].queen,
		x,y-self.tile_w*self.scale*3, 0,
		self.scale, self.scale
	)
	love.graphics.draw(
		Assets[color].rook,
		x,y-self.tile_w*self.scale*2, 0,
		self.scale, self.scale
	)
	love.graphics.draw(
		Assets[color].bishop,
		x,y-self.tile_w*self.scale, 0,
		self.scale, self.scale
	)
	love.graphics.draw(
		Assets[color].knight,
		x,y, 0,
		self.scale, self.scale
	)
end

function Board:draw_background()
	for i,square in ipairs(board_background) do
		local x,y = to_xy_coordinates(i-1)

		local tx = (x-1) * self.tile_w * self.scale + (self.screen_offset_x)
		local ty = (y-1) * self.tile_w * self.scale + (self.screen_offset_y)
		local high_w = self.tile_w*self.scale/3
		
		if square == 1
		then love.graphics.setColor(self.light_color)
		else love.graphics.setColor(self.dark_color)
		end
		love.graphics.rectangle('fill',
			tx,ty,
			self.tile_w*self.scale,
			self.tile_w*self.scale
		)

		if self.board_highlight[i] == 1 then
			--moveable square color
			love.graphics.setColor(0,0,0,.3)
			love.graphics.rectangle('fill',
				tx+self.tile_w*self.scale/2-high_w/2,
				ty+self.tile_w*self.scale/2-high_w/2,
				high_w,
				high_w
			)
		elseif self.board_highlight[i] == 2 then
			--capturable highlight color
			love.graphics.setColor(self.move_high)
			love.graphics.rectangle('fill',
				tx,ty,
				self.tile_w*self.scale,
				self.tile_w*self.scale
			)
		elseif self.board_highlight[i] == 3 then
			--last move highlight color
			love.graphics.setColor(self.last_move_high)
			love.graphics.rectangle('fill',
				tx,ty,
				self.tile_w*self.scale,
				self.tile_w*self.scale
			)	
		end

		if Options.display_attacks then
			if self.board_attacks[self.color_to_move][i] == 1 then
				love.graphics.setColor(.7,.1,.2,.5)
				love.graphics.rectangle('fill',
					tx,ty,
					self.tile_w*self.scale,
					self.tile_w*self.scale
				)
			end
		end
		
		--square # debugging
		--love.graphics.setColor(0,0,0,1)
		--love.graphics.setFont(Font_8)
		--love.graphics.print(tostring(i), tx+2, ty+2)
	end
end

function Board:draw_timers()
    local min_w = math.floor(math.fmod(self.w_time, 3600) / 60)
    local sec_w = math.floor(math.fmod(self.w_time, 60))
    local min_b = math.floor(math.fmod(self.b_time, 3600) / 60)
    local sec_b = math.floor(math.fmod(self.b_time, 60))
	if sec_w == 0 then sec_w = tostring(sec_w)..'0' elseif
	   sec_w < 10 then sec_w = '0'..tostring(sec_w) end
	if sec_b == 0 then sec_b = tostring(sec_b)..'0' elseif
	   sec_b < 10 then sec_b = '0'..tostring(sec_b) end

	love.graphics.setColor(self.light_color)
	love.graphics.setFont(Font_64)
	love.graphics.print(tostring(min_b)..':'..tostring(sec_b), 50, 100)
	love.graphics.print(tostring(min_w)..':'..tostring(sec_w), 50, Options.h-180)
end

function Board:select_piece(x,y)
	if self.promoting then return end
	if self.checkmate then return end
	if Options.ai_black and self.color_to_move == 0 then return end

	local tile = self:get_tile(x,y)
	if tile then
		local square = xy_to_index(tile.x,tile.y)
		local piece = self.board_pieces[square]
		if piece ~= 0 then --there's a piece on this square
			self.selected_piece = square
			--check for legal moves
			for _,move in ipairs(MoveGenerator.legal_moves) do
				local square_from = move[1]
				local square_to = move[2]
				local is_capture = self.board_pieces[square_to] ~= 0
				if square_from == square then
					--found a legal move
					if is_capture then self.board_highlight[square_to] = 2
					else self.board_highlight[square_to] = 1 end
				end
			end
		end
	end
end

function Board:mousereleased(x,y)
	if self.promoting then return end
	if not self.selected_piece then return end
	local tile = self:get_tile(x,y)
	if not tile then
		self.board_highlight = table_shallow_copy(blank_board)
		self.selected_piece = nil
		return
	end

	local square_from = self.selected_piece
	local square_to = xy_to_index(tile.x,tile.y)
	local move = MoveGenerator:contains_move(square_from, square_to)
	if move then
		local captured_piece = self.board_pieces[square_to]
		local is_capture = captured_piece ~= 0
		--make the move
		MoveGenerator:make_move(move)
		MoveGenerator.made_first_move = true
		
		--highlights
		self.board_attacks = MoveGenerator.attacks
		self.board_highlight = table_shallow_copy(blank_board)
		self.board_highlight[square_to] = 3
		self.board_highlight[square_from] = 3
		self.selected_piece = nil
		self.color_to_move = MoveGenerator.color_to_move

		if MoveGenerator.checkmate then
			SFX.check:play()
			SFX.checkmate:play()
			self.checkmate = MoveGenerator.color_to_move
			return
		else
			if is_capture or move[3].is_en_passant then
				if is_capture then
					table.insert(self.captured[self.color_to_move],captured_piece)
				elseif move[3].is_en_passant then
					table.insert(self.captured[self.color_to_move],1)
				end
				SFX.capture:play()
			else
				if move[3].is_castle then SFX.castle:play() else SFX.move:play() end
			end
			if MoveGenerator:is_in_check(self.color_to_move) then SFX.check:play() end
		end

		--Automatic AI Moves
		if Options.ai_black then
			self.searching = true
			love.thread.getChannel('board'):push({
				table_shallow_copy(MoveGenerator.board),
				table_shallow_copy(MoveGenerator.loyalty),
				table_shallow_copy(MoveGenerator.first_moves),
				MoveGenerator.king[0],
				MoveGenerator.king[1]
			})
			love.thread.getChannel('search'):push(true)
		else
			local moves = MoveGenerator:generate_pseudo_legal_moves()
			MoveGenerator.legal_moves = MoveGenerator:generate_legal_moves(moves)
		end
	else
		self.board_highlight = table_shallow_copy(blank_board)
		self.selected_piece = nil
	end
end

local function test_king_corner(friendly_king, enemy_king)
	local endgame_weight = 20
	local eval = 0

	local enemy_king_rank = math.floor((enemy_king-1)/8)+1
	local enemy_king_file = ((enemy_king-1) % 8)+1
	local enemy_king_dist_center_file = math.max(3-enemy_king_file,enemy_king_file-4)
	local enemy_king_dist_center_rank = math.max(3-enemy_king_rank,enemy_king_rank-4)
	local enemy_king_dist_center = enemy_king_dist_center_file+enemy_king_dist_center_rank
	eval = eval + enemy_king_dist_center

	local friendly_king_rank = math.floor((friendly_king-1)/8)+1
	local friendly_king_file = ((friendly_king-1) % 8)+1

	local dist_king_files = math.abs(friendly_king_file-enemy_king_file)
	local dist_king_ranks = math.abs(friendly_king_rank-enemy_king_rank)
	local dist_between_kings = dist_king_files+dist_king_ranks -- Manhattan
	--local dist_between_kings = max(dist_king_files,dist_king_ranks) --Chebyshev
	eval = eval + 14 - dist_between_kings

	print('eval: ', eval * endgame_weight)
end

function Board:ai_callback(best_move)
	print('Search completed in: ', self.search_time)
	self.search_time = 0
	self.searching = false
	self.message_sent = false
	local captured_piece = self.board_pieces[best_move[2]]
	local is_capture = captured_piece ~= 0
	MoveGenerator:make_move(best_move)

	--highlights
	self.board_attacks = MoveGenerator.attacks
	self.board_highlight = table_shallow_copy(blank_board)
	self.board_highlight[best_move[1]] = 3
	self.board_highlight[best_move[2]] = 3
	self.color_to_move = MoveGenerator.color_to_move

	--TESTING--
	--test_king_corner(self.king[1], self.king[0])

	if is_capture or best_move[3].is_en_passant then
		if is_capture then
			table.insert(self.captured[self.color_to_move],captured_piece)
		elseif best_move[3].is_en_passant then
			table.insert(self.captured[self.color_to_move],1)
		end
		SFX.capture:play()
	else
		if best_move[3].is_castle then SFX.castle:play() else SFX.move:play() end
	end
	if MoveGenerator:is_in_check(self.color_to_move) then SFX.check:play() end

	local moves = MoveGenerator:generate_pseudo_legal_moves()
	MoveGenerator.legal_moves = MoveGenerator:generate_legal_moves(moves)
	if MoveGenerator.checkmate then
		SFX.checkmate:play()
		self.checkmate = MoveGenerator.checkmate
	end
end

function Board:get_tile(x,y)
	for i,square in ipairs(board_background) do
		local _x,_y = to_xy_coordinates(i-1)

		local tx = (_x) * self.tile_w * self.scale + (self.screen_offset_x)
		local ty = (_y) * self.tile_w * self.scale + (self.screen_offset_y)
	
		if tx >= x and tx <= x + (self.tile_w*self.scale) and ty >= y and ty <= y + (self.tile_w*self.scale) then
			return {x=_x,y=_y}
		end
	end
end

function Board:test(ply)
	if Options.enable_profiler then Profiler.start() end
	print(MoveGenerator:generation_test(ply))
	if Options.enable_profiler then
		Profiler.stop()
		generate_report(Profiler.report(Options.profiler_lines))
	end
end

return Board