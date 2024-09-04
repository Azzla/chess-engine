local Board = {}
local MoveGenerator = require('func.MoveGenerator')
local PieceData = require('dicts.piece_data')
local Bot = require('class.Bot')
local FENParser = require('func.FENParser')
local Evaluation = require('func.eval')

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
	self.w_time				= 180 --3 minutes in seconds
	self.b_time				= 180 --3 minutes in seconds
	self.run_test			= nil

	FENParser.parse(_fen, self)
	MoveGenerator:init(self)
	local moves = MoveGenerator:generate_pseudo_legal_moves(self.color_to_move)
	MoveGenerator:generate_legal_moves(moves)
	self.board_attacks[1] = table_shallow_copy(MoveGenerator.attacks[self.color_to_move])

	-- Evaluation:init(
	-- 	Options.w-self.screen_offset_x+30,
	-- 	self.screen_offset_y,
	-- 	self.tile_w*self.squares*self.scale,
	-- 	self.board_pieces
	-- )
end

function Board:reset(_fen, to_move)
	self.board_loyalty		= table_add(table_shallow_copy(blank_board), -1)
	self.board_highlight	= table_shallow_copy(blank_board)
	self.board_attacks		= {
		[0] = table_shallow_copy(blank_board),
		[1] = table_shallow_copy(blank_board)
	}
	self.board_pieces		= table_shallow_copy(blank_board)
	self.board_first_move	= table_shallow_copy(blank_board)
	self.color_to_move		= to_move
	self.selected_piece		= nil
	self.promoting			= false
	self.w_time				= 180
	self.b_time				= 180
	self.run_test			= nil

	FENParser.parse(_fen, self)
	MoveGenerator:init(self, MoveGenerator.move_log)
	local moves = MoveGenerator:generate_pseudo_legal_moves(self.color_to_move)
	MoveGenerator:generate_legal_moves(moves)
	self.board_attacks[1] = table_shallow_copy(MoveGenerator.attacks[self.color_to_move])
end

function Board:update(dt)
	self:update_timers(dt)
	if self.color_to_move == 0 and Options.ai_black then --make the bot control black
		Bot:make_random(self)
	end
	self:promotion()
end

function Board:update_timers(dt)
	if not MoveGenerator.made_first_move then return end
	if self.checkmate ~= -1 then return end
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

function Board:draw_piece(piece, square, color)
	local piece_data = PieceData[piece]
	local x,y = to_xy_coordinates(square-1)
	local px = (x-1) * self.tile_w * self.scale + (self.screen_offset_x)
	local py = (y-1) * self.tile_w * self.scale + (self.screen_offset_y)
	local asset_color
	if color == 1 then asset_color = 'w' else asset_color = 'b' end

	if self.selected_piece == square then
		x,y = love.mouse.getPosition()
		love.graphics.setColor(.5,1,.5,1)
		love.graphics.draw(
			Assets[asset_color][piece_data.name],
			x,y,
			0,
			self.scale,self.scale,
			piece_data.dimensions[1]/2,
			piece_data.dimensions[2]/2
		)
	else
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(
			Assets[asset_color][piece_data.name],
			px,py,
			0,
			self.scale,self.scale,
			-(piece_data.offsets[1])-piece_data.dimensions[1]/2,
			-(piece_data.offsets[2])-piece_data.dimensions[2]/2
		)
	end
end

function Board:draw()
	self:draw_timers()
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
			love.graphics.rectangle('fill',tx+33,ty+33,45,45)
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

		love.graphics.setColor(0,0,0,1)
		love.graphics.setFont(Font_8)
		love.graphics.print(tostring(i), tx+2, ty+2)
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
		local is_capture = self.board_pieces[square_to] ~= 0
		--make the move
		MoveGenerator:make_move(move)
		local moves = MoveGenerator:generate_pseudo_legal_moves()
		MoveGenerator:generate_legal_moves(moves)
		
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
			if is_capture then SFX.capture:play() else
				if move[3].is_castle then SFX.castle:play() else SFX.move:play() end
			end
			if MoveGenerator:is_in_check(self.color_to_move) then SFX.check:play() end
		end
	else
		self.board_highlight = table_shallow_copy(blank_board)
		self.selected_piece = nil
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

-- function Board:step()
-- 	if #MoveGenerator.move_log > 0 then
-- 		local move = MoveGenerator.move_log[self.step_i]
-- 		if not move then return end
-- 		if move[2] == true then
-- 			MoveGenerator:unmake_move(move[1])
-- 			self.step_i = self.step_i + 1
-- 		else
-- 			MoveGenerator:make_move(move)
-- 			self.step_i = self.step_i + 1

-- 			self.board_highlight = table_shallow_copy(blank_board)
-- 			self.board_highlight[move[1]] = 3
-- 			self.board_highlight[move[2]] = 3
-- 		end
-- 	end
-- end

return Board