local Board = {}
local MoveData,DirectionOffsets = require('dicts.move_data')()
local Unit = require('class.Unit')
local Bot = require('class.Bot')
local FENParser = require('func.FENParser')
local Evaluation = require('func.eval')

--these are used to filter out invalid moves
local a_file = {1,9,17,25,33,41,49,59}
local ab_file = {1,9,17,25,33,41,49,59,2,10,18,26,34,42,50,58}
local gh_file = {7,15,23,31,39,47,55,63,8,16,24,32,40,48,56,64}
local h_file = {8,16,24,32,40,48,56,64}

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

local function table_shallow_copy(t)
	local t2 = {}
		for k,v in pairs(t) do
			t2[k] = v
		end
	return t2
end

local function table_contains(table, element)
	for _, value in pairs(table) do
		if value == element then return true end
	end
	return false
end

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

function Board:init(scale, _fen)
	self.scale = scale or 1
	self.squares = 8
	self.ui = SUIT.new()
	self.light_color = {love.math.colorFromBytes(235,236,208,255)}
	self.dark_color = {love.math.colorFromBytes(115,149,82,255)}
	self.move_high = {love.math.colorFromBytes(235,97,80,204)}
	self.last_move_high = {love.math.colorFromBytes(255,255,51,127)}

	-- 1 = white; 0 = black;
	self.board_background = {
		1,0,1,0,1,0,1,0,
		0,1,0,1,0,1,0,1,
		1,0,1,0,1,0,1,0,
		0,1,0,1,0,1,0,1,
		1,0,1,0,1,0,1,0,
		0,1,0,1,0,1,0,1,
		1,0,1,0,1,0,1,0,
		0,1,0,1,0,1,0,1
	}

	-- 1 = white; 0 = none; -1 = black;
	self.board_loyalty = table_shallow_copy(blank_board)

	-- 0 = normal; 1 = highlighted
	self.board_highlight = table_shallow_copy(blank_board)

	-- 0 = none; 1 = pawn; 2 = knight; 3 = bishop; 4 = rook; 5 = king; 6 = queen;
	self.board_pieces = table_shallow_copy(blank_board)
	self.board_copy = table_shallow_copy(blank_board) --used to copy the previous board state

	self.tile_w				= 450
	self.screen_offset_x	= (Options.w - (self.tile_w*self.squares*self.scale))/2
	self.screen_offset_y	= (Options.h - (self.tile_w*self.squares*self.scale))/2
	self.unit_selected		= nil --tracks a selected unit
	self.color_to_move		= 1 --1 = white; 0 = black;

	--[1]=_id of the piece that moved
	--[2]=index of the square moved to
	--[3]=was it the first move, 1=yes,0=no
	--[4]=offset of the move, 16 or -16 of special note for en passant
	self.last_move			= {-1,-1,false,0}

	self.was_en_passant		= false --becomes the unit to be captured by en passant
	self.can_castle_l		= false --becomes the rook to move with the king
	self.can_castle_r		= false --becomes the rook to move with the king
	self.is_in_check		= -1 -- 1 for white, 0 for black
	self.checkmate			= -1 -- 1 for white, black wins; 0 for black, white wins
	self.promoting			= false --enables the interface for selecting a promotion piece
	self.w_time				= 180 --3 minutes in seconds
	self.b_time				= 180 --3 minutes in seconds

	FENParser.parse(_fen, self)
	self:populate()

	Evaluation:init(
		Options.w-self.screen_offset_x+30,
		self.screen_offset_y,
		self.tile_w*self.squares*self.scale,
		self.board_pieces
	)
end

function Board:reset(_fen)
	self.board_loyalty		= table_shallow_copy(blank_board)
	self.board_highlight	= table_shallow_copy(blank_board)
	self.board_pieces		= table_shallow_copy(blank_board)
	self.board_copy			= table_shallow_copy(blank_board)
	self.unit_selected		= nil --tracks a selected unit
	self.color_to_move		= 1 --1 = white; 0 = black;
	self.last_move			= {-1,-1,false,0}
	self.was_en_passant		= false
	self.can_castle_l		= false
	self.can_castle_r		= false
	self.is_in_check		= -1
	self.checkmate			= -1
	self.promoting			= false
	self.w_time				= 180 --seconds
	self.b_time				= 180 --seconds

	FENParser.parse(_fen, self)
	self:populate()
	Evaluation:eval(self.board_pieces)
end

function Board:populate()
	for i,piece in ipairs(self.board_pieces) do
		if piece ~= 0 then
			local unit = Unit(
				piece,
				i-1,
				self.board_loyalty[i],
				self.tile_w,
				self.screen_offset_x,
				self.screen_offset_y,
				self.scale
			)
			self.board_pieces[i] = unit
		end
	end
end

function Board:update(dt)
	self:update_timers(dt)
	Evaluation:update(dt)
	if self.color_to_move == 0 and Options.ai_black then --make the bot control black
		Bot:make_random(self)
	end

	if not self.promoting then return end
	local btn_w = self.tile_w*self.scale
	local x,y = self.promoting.x, self.promoting.y
	local index = self.promoting.index
	local loyalty = self.promoting.color
	--Auto-Queen Options--
	if Options.auto_queen or loyalty == 0 then
		self:promote(index, loyalty, 6)
		self.promoting = false
		return
	end

	local color = self.promoting.asset_color
	if loyalty == 0 then y = y-btn_w*3 end

	self.ui.layout:reset(x-btn_w,y)
	local queen_btn = self.ui:Button("", {id=6}, self.ui.layout:row(btn_w,btn_w))
	local rook_btn = self.ui:Button("", {id=4}, self.ui.layout:row())
	local bishop_btn = self.ui:Button("", {id=3}, self.ui.layout:row())
	local knight_btn = self.ui:Button("", {id=2}, self.ui.layout:row())

	if queen_btn.hit then
		self:promote(index, loyalty, queen_btn.id)
		self.promoting = false
	end
	if rook_btn.hit then
		self:promote(index, loyalty, rook_btn.id)
		self.promoting = false
	end
	if bishop_btn.hit then
		self:promote(index, loyalty, bishop_btn.id)
		self.promoting = false
	end
	if knight_btn.hit then
		self:promote(index, loyalty, knight_btn.id)
		self.promoting = false
	end
end

function Board:update_timers(dt)
	local white_moved = self.last_move[1] ~= -1
	if not white_moved then return end
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

function Board:draw()
	self:draw_timers()
	Evaluation:draw()
	for i,unit in ipairs(self.board_pieces) do
		if unit ~= 0 then
			if not unit.selected then
				unit:draw()
			else
				unit:draw_hover(love.mouse.getPosition())
			end
		end
	end
	if self.promoting then
		self.ui:draw()
		self:draw_promotion_buttons(self.promoting.asset_color)
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
	for i,square in ipairs(self.board_background) do
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
	love.graphics.print(tostring(min_b)..':'..tostring(sec_b), 50, 100)
	love.graphics.print(tostring(min_w)..':'..tostring(sec_w), 50, Options.h-180)
end

function Board:select_piece(x,y,i)
	if self.promoting then return end

	local tile = self:get_tile(x,y)
	if i or tile then
		local index = i or xy_to_index(tile.x,tile.y)
		local unit = self.board_pieces[index]
		if unit ~= 0 then --there's a piece on this square
			self.unit_selected = unit
			unit.selected = true
			self:generate_moves(unit)
		end
	end
end

function Board:test_move(piece, new_index, board)
	board[piece.index] = 0
	board[new_index] = piece
	local move_valid = true

	for i,p in ipairs(board) do
		if p ~= 0 and p.color ~= piece.color then
			local move_data = MoveData[i]
			--test enemy piece possible captures of king
			if p.piece == "pawn" then
				if self:pawn_check(p, move_data, board) then move_valid = false end
			elseif p.piece == "knight" then
				if self:knight_check(p, move_data, board) then move_valid = false end
			elseif p.info.sliding then
				if self:sliding_check(p, move_data, board) then move_valid = false end
			else
				--we have to test if king "checks" are possible in order to
				--disallow both kings from moving into each other's capture radius.
				if self:king_check(p, move_data, board) then move_valid = false end
			end
		end
	end

	return move_valid
end

--TODO: Rigorize.  Maybe a deep copy of the board state,
--or a flat table recognizing only piece ID's, not table references.
--Needs to fix capturing, promoting, and castling.
function Board:undo_move()
	if not self.last_move[1] then return end
	local piece = self.board_pieces[self.last_move[2]]
	local was_first_move = self.last_move[3]
	piece:move(self.last_move[5])
	if was_first_move then piece.first_move = true end

	self.board_pieces = self.board_copy
	self.color_to_move = 1 - self.color_to_move
	self.board_highlight = table_shallow_copy(blank_board)
	self.last_move = {false}
end

function Board:move_piece(x,y, i)
	if self.promoting then return end
	if not self.unit_selected then
		self.board_highlight = table_shallow_copy(blank_board)
		return
	end

	local tile = self:get_tile(x,y)
	local prev_index = self.unit_selected.index
	local index

	if i or tile then --did we click a valid tile? 
		index = i or xy_to_index(tile.x,tile.y)

		if self:check_valid_move(index) then --is the tile a valid move for the selected piece?
			--copy the previous board state so we can undo moves
			self.board_copy = table_shallow_copy(self.board_pieces)

			self.is_in_check = -1
			local target_unit = self.board_pieces[index]
			if target_unit ~= 0 then
				--capture this piece
				--target_unit:kill()
				SFX.capture:play()
			end

			if self.was_en_passant and self.board_highlight[index] == 2 then
				self.board_pieces[self.was_en_passant.index] = 0
				--self.was_en_passant:kill()
				SFX.capture:play()
			end
			self.was_en_passant = false

			--reflect the move on the board state
			self.board_pieces[prev_index] = 0
			self.board_pieces[index] = self.unit_selected

			--store the move as the last move played
			self.last_move = {
				self.unit_selected.info._id, --piece type
				index, --index it moved to
				self.unit_selected.first_move, --was it that piece's first move
				prev_index-index, --index offset of the move
				prev_index --index it move from
			}
			----------------------------------------

			--move the selected piece to the new square
			self.unit_selected:move(index)
			
			--check if the move was to castle the king left or right
			if self.can_castle_l and prev_index == index+2 then
				--move the rook
				local new_rook_i = self.unit_selected.index+1
				self.board_pieces[new_rook_i] = self.board_pieces[self.can_castle_l.index]
				self.board_pieces[self.can_castle_l.index] = 0
				self.can_castle_l:move(new_rook_i)

				SFX.castle:play()
				self.can_castle_l = false
				self.can_castle_r = false
			elseif self.can_castle_r and prev_index == index-2 then
				local new_rook_i = self.unit_selected.index-1
				self.board_pieces[new_rook_i] = self.board_pieces[self.can_castle_r.index]
				self.board_pieces[self.can_castle_r.index] = 0
				self.can_castle_r:move(new_rook_i)

				SFX.castle:play()
				self.can_castle_l = false
				self.can_castle_r = false
			end

			--if it's a pawn, check for promotion
			if self.unit_selected.piece == "pawn" then self:check_promotion(self.unit_selected) end

			--check if the king is in check or checkmate
			self:check_checkmate(self.unit_selected)

			--switch who's turn it is
			self.color_to_move = 1 - self.color_to_move

			--update the eval bar
			Evaluation:eval(self.board_pieces)
		else
			self.was_en_passant = false
		end
	end

	self.unit_selected.selected = false
	self.unit_selected = nil
	self.can_castle_l = false
	self.can_castle_r = false

	--reset board highlights and add last-move highlight
	self.board_highlight = table_shallow_copy(blank_board)
	self.board_highlight[prev_index] = 3
	if index then self.board_highlight[index] = 3 end
end

function Board:get_tile(x,y)
	for i,square in ipairs(self.board_background) do
		local _x,_y = to_xy_coordinates(i-1)

		local tx = (_x) * self.tile_w * self.scale + (self.screen_offset_x)
		local ty = (_y) * self.tile_w * self.scale + (self.screen_offset_y)
	
		if tx >= x and tx <= x + (self.tile_w*self.scale) and ty >= y and ty <= y + (self.tile_w*self.scale) then
			return {x=_x,y=_y}
		end
	end
end

local function combine_boards(...)
	local combined_board = table_shallow_copy(blank_board)
	for _,board in ipairs({...}) do
		for i,v in ipairs(board) do
			if (v == 1 or v == 2) then combined_board[i] = v end
		end
	end
	return combined_board
end
local function table_bitwise_OR(t1,t2)
	for i,v in ipairs(t2) do
		if v == 1 or v == 2 then t1[i] = v end
	end
	return t1
end

function Board:generate_possible_moves(color)
	--track separate boards for every piece
	local pawn_board	= table_shallow_copy(blank_board)
	local knight_board	= table_shallow_copy(blank_board)
	local sliding_board	= table_shallow_copy(blank_board)
	local king_board	= table_shallow_copy(blank_board)
	local piece_board	= table_shallow_copy(self.board_pieces)
	
	for i,unit in ipairs(piece_board) do
		if unit ~= 0 and unit.color == color then
			local move_data = MoveData[i]

			if unit.piece == 'pawn' then
				local board = table_shallow_copy(blank_board)
				self:pawn_moves(unit, move_data, board)
				self:filter_illegal_moves(unit, board)
				pawn_board = table_bitwise_OR(pawn_board, board)
			elseif unit.piece == 'knight' then
				local board = table_shallow_copy(blank_board)
				self:knight_moves(unit, move_data, board)
				self:filter_illegal_moves(unit, board)
				knight_board = table_bitwise_OR(knight_board, board)
			elseif unit.info.sliding then
				local board = table_shallow_copy(blank_board)
				self:sliding_moves(unit, move_data, board)
				self:filter_illegal_moves(unit, board)
				sliding_board = table_bitwise_OR(sliding_board, board)
			elseif unit.piece == 'king' then
				self:king_moves(unit, move_data, king_board)
				self:filter_illegal_moves(unit, king_board)
			end
		end
	end
	

	--combine them all to check if there are any available moves
	return combine_boards(pawn_board, knight_board, sliding_board, king_board)
end

function Board:generate_moves(unit)
	if unit.color ~= self.color_to_move then return end --we only consider the side who's turn to move it is.
	local move_data = MoveData[unit.index]

	if unit.piece == "pawn" then
		self:pawn_moves(unit, move_data)
		self:filter_illegal_moves(unit)
	elseif unit.piece == "knight" then
		self:knight_moves(unit, move_data)
		self:filter_illegal_moves(unit)
	elseif unit.info.sliding then
		self:sliding_moves(unit, move_data)
		self:filter_illegal_moves(unit)
	else
		self:king_moves(unit, move_data)
		self:filter_illegal_moves(unit)
	end
end

function Board:filter_illegal_moves(piece, board)
	local moves_board = board or self.board_highlight
	for i,square in ipairs(moves_board) do
		--for each potential move, we try it out on a test board
		--and see if any of the opponents responses is a capture of the king.
		--If it is, we know our potential move was illegal, so we remove it
		--from the possible moves it can play.
		if square == 1 or square == 2 then
			local test_board = table_shallow_copy(self.board_pieces)
			local valid = self:test_move(piece, i, test_board)
			if not valid then moves_board[i] = 0 end
		end
	end
end

function Board:pawn_moves(unit, move_data, board)
	local moves_board = board or self.board_highlight

	local offsets
	if unit.first_move then
		offsets = unit.info[unit.asset_color].move_1
	else
		offsets = unit.info[unit.asset_color].move
	end

	--check for possible captures
	local offsets_cap = unit.info[unit.asset_color].move_cap
	for _,offset in ipairs(offsets_cap) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square
		and target_square ~= 0
		and target_square.color ~= unit.color
		and not self:check_discard_pawn(unit.index, target_index) then
			moves_board[target_index] = 2
		end
	end

	--regular moves
	for _,offset in ipairs(offsets) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square == 0 then
			--square is empty
			moves_board[target_index] = 1
		else
			--on move 1, if there is a piece in front of the pawn it can't skip
			--over it to move two squares. so we stop here.
			return
		end
	end

	--check en passant
	self:check_en_passant(unit, moves_board)
end

function Board:check_en_passant(pawn, moves_board)
	local left = self.board_pieces[pawn.index-1]
	local right = self.board_pieces[pawn.index+1]

	if left and left ~= 0 then
		if self.last_move[1] == 1
			and self.last_move[2] == pawn.index-1
			and self.last_move[3]
			and (self.last_move[4] == 16 or self.last_move[4] == -16)
		then
			if pawn.color == 1 and not self:check_discard_pawn(pawn.index,pawn.index-9) then
				moves_board[pawn.index-9] = 2
				self.was_en_passant = left
			elseif not self:check_discard_pawn(pawn.index,pawn.index+7) then
				moves_board[pawn.index+7] = 2
				self.was_en_passant = left
			end
		end
	end
	if right and right ~= 0 then
		if self.last_move[1] == 1
			and self.last_move[2] == pawn.index+1
			and self.last_move[3]
			and (self.last_move[4] == 16 or self.last_move[4] == -16)
		then
			if pawn.color == 1 and not self:check_discard_pawn(pawn.index,pawn.index-7) then
				moves_board[pawn.index-7] = 2
				self.was_en_passant = right
			elseif not self:check_discard_pawn(pawn.index,pawn.index+9) then
				moves_board[pawn.index+9] = 2
				self.was_en_passant = right
			end
		end
	end
end

function Board:check_discard_pawn(pawn_i,target_i)
	if table_contains(a_file, pawn_i) then
		if table_contains(h_file, target_i) then return true end
	elseif table_contains(h_file, pawn_i) then
		if table_contains(a_file, target_i) then return true end
	end
	return false
end

function Board:knight_moves(unit, move_data, board)
	local moves_board = board or self.board_highlight

	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square and not self:check_discard_knight(unit.index, target_index) then
			if target_square == 0 then
				moves_board[target_index] = 1
			elseif target_square.color ~= unit.color then
				moves_board[target_index] = 2
			end
		end
	end
end

function Board:check_discard_knight(knight_i, target_i)
	if table_contains(ab_file, knight_i) then
		if table_contains(gh_file, target_i) then return true end
	elseif table_contains(gh_file, knight_i) then
		if table_contains(ab_file, target_i) then return true end
	end
	return false
end

function Board:king_moves(unit, move_data, board)
	local moves_board = board or self.board_highlight

	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square and not self:check_discard_pawn(unit.index, target_index) then
			if target_square == 0 then
				moves_board[target_index] = 1
			elseif target_square.color ~= unit.color then
				moves_board[target_index] = 2
			end
		end
	end

	self:check_castling(unit, moves_board)
end

--TODO: Something is totally f****d with castling. Sometimes a promoted
--rook can castle with the enemy king, even if the king has already moved and
--there are pieces in-between.  No idea why.
function Board:check_castling(king, moves_board)
	if not king.first_move or self.is_in_check == king.color then
		self.can_castle_l = false
		self.can_castle_r = false
		return
	end
	for i,p in ipairs(self.board_pieces) do
		if p ~= 0
		and king.color == p.color
		and p.piece == "rook"
		and p.first_move
		then
			--check if the squares between the rook & king are empty
			if p.index < king.index then --rook is to the left of king
				local start_i = p.index+1
				local end_i = king.index-1
				for index=start_i,end_i do
					local square = self.board_pieces[index]
					if square ~= 0 then goto continue end
				end
				--if we made it here, then castling is legal
				moves_board[king.index-2] = 1
				self.can_castle_l = p
			elseif p.index > king.index then --rook is to the right of king
				local start_i = p.index-1
				local end_i = king.index+1
				for index=start_i,end_i do
					local square = self.board_pieces[index]
					if square ~= 0 then goto continue end
				end
				--if we made it here, then castling is legal
				moves_board[king.index+2] = 1
				self.can_castle_r = p
			end
		end
		::continue::
	end
end

function Board:sliding_moves(unit, move_data, board)
	local moves_board = board or self.board_highlight
	local start_dir = 1
	local end_dir = 8

	if unit.piece == "rook" then
		end_dir = 4
	end
	if unit.piece == "bishop" then
		start_dir = 5
	end

	for dir=start_dir,end_dir do
		for i=1,move_data[dir] do
			local target_index = unit.index + DirectionOffsets[dir] * i
			local target_square= self.board_pieces[target_index]
			if not target_square then --off the board
				dir = dir + 1 --skip to the next direction
				goto continue
			else
				if target_square == 0 then --square is empty
					moves_board[target_index] = 1
				else
					if target_square.color == unit.color then --square contains allied piece
						dir = dir + 1
						goto continue
					else
						--target square's piece can be captured,
						--but no more moves are possible in that direction
						moves_board[target_index] = 2
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
end

--TODO: Fix "discover" check detection. This function only checks whether
--the just-moved piece gave a check, but not whether it "revealed" one on
--the enemy king from an allied sliding piece.
function Board:check_checkmate(unit)
	--test for check from this unit
	if unit.piece == "pawn" then
		local move_data = MoveData[unit.index]
		self:pawn_check(unit, move_data)
	elseif unit.piece == "knight" then
		local move_data = MoveData[unit.index]
		self:knight_check(unit, move_data)
	elseif unit.info.sliding then
		local move_data = MoveData[unit.index]
		self:sliding_check(unit, move_data)
	end

	--test for "discover" check from ally sliding pieces
	for i,piece in ipairs(self.board_pieces) do
		if piece
		and piece ~= 0
		and piece.color == unit.color
		and piece.info.sliding
		then
			local move_data = MoveData[i]
			self:sliding_check(piece, move_data)
		end
	end

	--if check, test for checkmate
	if self.is_in_check ~= -1 then
		local any_legal_moves = false
		local opponent = 1 - unit.color

		local possible_moves = self:generate_possible_moves(opponent)
		for i,square in ipairs(possible_moves) do
			if square == 1 or square == 2 then
				any_legal_moves = true
			end
		end
		if not any_legal_moves then
			SFX.check:play()
			SFX.checkmate:play()
			self.checkmate = opponent
		else
			SFX.check:play()
		end
	else
		SFX.move:play()
	end
end

function Board:pawn_check(unit, move_data, is_test_board)
	local board = is_test_board or self.board_pieces
	--check for possible captures
	local offsets_cap = unit.info[unit.asset_color].move_cap
	for _,offset in ipairs(offsets_cap) do
		local target_index = unit.index + offset
		local target_square = board[target_index]

		if target_square
		and target_square ~= 0
		and target_square.color ~= unit.color
		and target_square.piece == 'king' then
			if is_test_board then return true end
			self.is_in_check = target_square.color
		end
	end
	return false
end

function Board:knight_check(unit, move_data, is_test_board)
	local board = is_test_board or self.board_pieces

	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = board[target_index]

		if target_square then
			if target_square ~= 0
			and target_square.color ~= unit.color
			and target_square.piece == 'king' then
				if is_test_board then return true end
				self.is_in_check = target_square.color
			end
		end
	end
	return false
end

function Board:sliding_check(unit, move_data, is_test_board)
	local board = is_test_board or self.board_pieces
	local start_dir = 1
	local end_dir = 8
	if unit.piece == "rook" then end_dir = 4 end
	if unit.piece == "bishop" then start_dir = 5 end

	for dir=start_dir,end_dir do
		for i=1,move_data[dir] do
			local target_index = unit.index + DirectionOffsets[dir] * i
			local target_square= board[target_index]

			if not target_square then
				dir = dir + 1
				goto continue
			else
				if target_square ~= 0 then
					if target_square.color == unit.color then --square contains allied piece
						dir = dir + 1
						goto continue
					else
						--target square's piece can be captured,
						--but no more moves are possible in that direction
						if target_square.piece == 'king' then
							if is_test_board then return true end
							self.is_in_check = target_square.color
						end
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
	return false
end

function Board:king_check(unit, move_data, is_test_board)
	local board = is_test_board or self.board_pieces

	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = board[target_index]

		if target_square then
			if target_square == 0 then
			elseif target_square.color ~= unit.color then
				if target_square.piece == 'king' then return true end
			end
		end
	end
end

function Board:check_valid_move(new_index)
	if self.board_highlight[new_index] == 1 or self.board_highlight[new_index] == 2 then
		return true
	end
	return false
end

function Board:check_promotion(pawn)
	if pawn.color == 1 and pawn.index >= 1 and pawn.index <= 8 then
		self.promoting = pawn
	end
	if pawn.color == 0 and pawn.index >= 57 and pawn.index <= 64 then
		self.promoting = pawn
	end
end

function Board:promote(index, color, to_piece_id)
	local piece = Unit(
		to_piece_id,
		index-1,
		color,
		self.tile_w,
		self.screen_offset_x,
		self.screen_offset_y,
		self.scale
	)
	self.board_pieces[index] = piece
	self:check_checkmate(piece)
	SFX.promote:play()

	--update the eval bar
	Evaluation:eval(self.board_pieces)
end

return Board