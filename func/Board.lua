local Board = {}
local MoveData,DirectionOffsets = require('dicts.move_data')()
local Unit = require('class.Unit')
local FENParser = require('func.FENParser')

--these are used to filter out invalid moves
local a_file = {1,9,17,25,33,41,49,59}
local ab_file = {1,9,17,25,33,41,49,59,2,10,18,26,34,42,50,58}
local gh_file = {7,15,23,31,39,47,55,63,8,16,24,32,40,48,56,64}
local h_file = {16,24,32,40,48,56,64}

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

	self.tile_w				= Assets.square_light:getWidth()
	self.screen_offset_x	= (Options.w - (self.tile_w*self.squares*self.scale))/2
	self.screen_offset_y	= (Options.h - (self.tile_w*self.squares*self.scale))-50
	self.units				= {}
	self.unit_selected		= nil --tracks a selected unit
	self.color_to_move		= 1 --1 = white; 0 = black;

	--this tracks the last move played;
	--[1]=_id of the piece that moved
	--[2]=index of the square moved to
	--[3]=was it the first move, 1=yes,0=no
	self.last_move			= {-1,-1,false}
	self.was_en_passant		= false --becomes the unit to be captured by en passant
	self.is_in_check		= -1 -- 1 for white, 0 for black

	FENParser.parse(_fen, self)
	self:populate()
end

function Board:populate()
	for i,piece in ipairs(self.board_pieces) do
		if piece ~= 0 then
			local unit = Unit(piece, i-1, self.board_loyalty[i], self.tile_w, self.screen_offset_x, self.screen_offset_y, self.scale)
			self.board_pieces[i] = unit
		end
	end
end

function Board:draw()
	for i,unit in ipairs(self.board_pieces) do
		if unit ~= 0 then
			if not unit.selected then
				unit:draw()
			else
				unit:draw_hover(love.mouse.getPosition())
			end
		end
	end
end

function Board:draw_background()
	for i,square in ipairs(self.board_background) do
		local x,y = to_xy_coordinates(i-1)

		local tx = (x-1) * self.tile_w * self.scale + (self.screen_offset_x)
		local ty = (y-1) * self.tile_w * self.scale + (self.screen_offset_y)
		
		love.graphics.setColor(1,1,1,1)
		if square == 1 then
			love.graphics.draw(Assets.square_light,tx,ty,0,self.scale,self.scale)
		else
			love.graphics.draw(Assets.square_dark,tx,ty,0,self.scale,self.scale)
		end
		
		love.graphics.setFont(Font_16)
		love.graphics.print(tostring(i), tx+2, ty)

		if self.board_highlight[i] == 1 then
			love.graphics.setColor(.5,.8,1,1)
			love.graphics.rectangle('fill',tx+12,ty+12,451*.20,451*.20)
		end
	end
end

function Board:select_piece(x,y)
	local tile = self:get_tile(x,y)
	if tile then
		local index = xy_to_index(tile.x,tile.y)
		local unit = self.board_pieces[index]
		if unit ~= 0 then --there's a piece on this square
			self.unit_selected = unit
			unit.selected = true
			self:generate_moves(unit)
		end
	end
end

function Board:move_piece(x,y)
	if not self.unit_selected then
		self.board_highlight = table_shallow_copy(blank_board)
		return
	end

	local tile = self:get_tile(x,y)
	if tile then --did we click a valid tile? 
		local index = xy_to_index(tile.x,tile.y)

		if self:check_valid_move(index) then --is the tile a valid move for the selected piece?
			local target_unit = self.board_pieces[index]
			if target_unit ~= 0 then
				--capture this piece
				target_unit:kill()
				SFX.capture:play()
			else SFX.move:play() end

			if self.was_en_passant then
				self.board_pieces[self.was_en_passant.index] = 0
				self.was_en_passant:kill()
				SFX.capture:play()
				self.was_en_passant = false
			end

			--reflect the move on the board state
			self.board_pieces[self.unit_selected.index] = 0
			self.board_pieces[index] = self.unit_selected

			--store the move as the last move played
			self.last_move = { self.unit_selected.info._id, index, self.unit_selected.first_move }

			--move the selected piece to the new square
			self.unit_selected:move(index,tile)

			--if it's a pawn, check for promotion
			if self.unit_selected.piece == "pawn" then self:check_promotion(self.unit_selected) end

			--check if the king is in check or checkmate
			self:check_checkmate(self.unit_selected)

			--switch who's turn it is
			self.color_to_move = 1 - self.color_to_move
		else
			self.was_en_passant = false
		end
	end
	self.unit_selected.selected = false
	self.unit_selected = nil
	self.board_highlight = table_shallow_copy(blank_board)
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

--TODO:
--Castling, Checkmate, King Can't Move Into Check
function Board:generate_moves(unit)
	if unit.color ~= self.color_to_move then return end --we only consider the side who's turn to move it is.
	local move_data = MoveData[unit.index]

	if unit.piece == "pawn" then
		self:pawn_moves(unit, move_data)
	elseif unit.piece == "knight" then
		self:knight_moves(unit, move_data)
	elseif unit.info.sliding then
		self:sliding_moves(unit, move_data)
	else
		self:king_moves(unit, move_data)
	end
end

function Board:pawn_moves(unit, move_data)
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

		if target_square ~= 0 and target_square.color ~= unit.color then
			self.board_highlight[target_index] = 1
		end
	end

	--regular moves
	for _,offset in ipairs(offsets) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square == 0 then
			--square is empty
			self.board_highlight[target_index] = 1
		else
			--on move 1, if there is a piece in front of the pawn it can't skip
			--over it to move two squares. so we stop here.
			return
		end
	end

	--check en passant
	self:check_en_passant(unit)
end

function Board:check_en_passant(pawn)
	local left = self.board_pieces[pawn.index-1]
	local right = self.board_pieces[pawn.index+1]
	if left and left ~= 0 then
		if self.last_move[1] == 1
			and self.last_move[2] == pawn.index-1
			and self.last_move[3]
		then
			if pawn.color == 1 and not self:check_discard_pawn(pawn.index,pawn.index-9) then
				self.board_highlight[pawn.index-9] = 1
				self.was_en_passant = left
			elseif not self:check_discard_pawn(pawn.index,pawn.index+7) then
				self.board_highlight[pawn.index+7] = 1
				self.was_en_passant = left
			end
		end
	end
	if right and right ~= 0 then
		if self.last_move[1] == 1
			and self.last_move[2] == pawn.index+1
			and self.last_move[3]
		then
			if pawn.color == 1 and not self:check_discard_pawn(pawn.index,pawn.index-7) then
				self.board_highlight[pawn.index-7] = 1
				self.was_en_passant = right
			elseif not self:check_discard_pawn(pawn.index,pawn.index+9) then
				self.board_highlight[pawn.index+9] = 1
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

function Board:knight_moves(unit, move_data)
	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square and not self:check_discard_knight(unit.index, target_index) then
			if target_square == 0 then
				self.board_highlight[target_index] = 1
			elseif target_square.color ~= unit.color then
				self.board_highlight[target_index] = 1
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

function Board:king_moves(unit, move_data)
	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square then
			if target_square == 0 then
				self.board_highlight[target_index] = 1
			elseif target_square.color ~= unit.color then
				self.board_highlight[target_index] = 1
			end
		end
	end
end

function Board:sliding_moves(unit, move_data)
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
					self.board_highlight[target_index] = 1
				else
					if target_square.color == unit.color then --square contains allied piece
						dir = dir + 1
						goto continue
					else
						--target square's piece can be captured,
						--but no more moves are possible in that direction
						self.board_highlight[target_index] = 1
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
end

function Board:check_checkmate(unit)
	local move_data = MoveData[unit.index]
	if unit.piece == "pawn" then
		self:pawn_check(unit, move_data)
	elseif unit.piece == "knight" then
		self:knight_check(unit, move_data)
	elseif unit.info.sliding then
		self:sliding_check(unit, move_data)
	end
end

function Board:pawn_check(unit, move_data)
	--check for possible captures
	local offsets_cap = unit.info[unit.asset_color].move_cap
	for _,offset in ipairs(offsets_cap) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square ~= 0
		and target_square.color ~= unit.color
		and target_square.piece == 'king' then
			self.is_in_check = target_square.color
			SFX.check:play()
		end
	end
end

function Board:knight_check(unit, move_data)
	for _,offset in ipairs(unit.info.move) do
		local target_index = unit.index + offset
		local target_square = self.board_pieces[target_index]

		if target_square then
			if target_square ~= 0
			and target_square.color ~= unit.color
			and target_square.piece == 'king' then
				self.is_in_check = target_square.color
				SFX.check:play()
			end
		end
	end
end

function Board:sliding_check(unit, move_data)
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
				else
					if target_square.color == unit.color then --square contains allied piece
						dir = dir + 1
						goto continue
					else
						--target square's piece can be captured,
						--but no more moves are possible in that direction
						if target_square.piece == 'king' then
							self.is_in_check = target_square.color
							SFX.check:play()
						end
						dir = dir + 1
						goto continue
					end
				end
			end
		end
		::continue::
	end
end

function Board:check_valid_move(new_index)
	if self.board_highlight[new_index] == 1 then return true end
	return false
end

function Board:check_promotion(pawn)
	if pawn.color == 1 and pawn.index >= 1 and pawn.index <= 8 then
		self:promote(pawn)
	end
	if pawn.color == 0 and pawn.index >= 57 and pawn.index <= 64 then
		self:promote(pawn)
	end
end

function Board:promote(pawn)
	local index = pawn.index
	local queen = Unit(
		6, --auto-queen for now
		index-1,
		pawn.color,
		self.tile_w,
		self.screen_offset_x,
		self.screen_offset_y,
		self.scale
	)
	self.board_pieces[index] = queen
	self.unit_selected = queen
	SFX.promote:play()
end

return Board