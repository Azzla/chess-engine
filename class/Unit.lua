local Unit = Class{}
local Unit_Dictionary = require('dicts.units')

local function to_xy_tile(index)
	local grid_size = 8

	local x = index % grid_size + 1
	local y = math.floor(index / grid_size) + 1

	return {x=x,y=y}
end

function Unit:init(piece, index, loyalty, tile_w, screen_x, screen_y, scale)
	self.piece		= self:get_piece(piece) --string
	self.info		= Unit_Dictionary[self.piece]
	self.color		= self:get_color(loyalty)
	self.asset_color= self:get_asset_color(loyalty)
	self.index		= index+1
	self.tile		= to_xy_tile(index) -- {<row>,<column>}
	self.tile_w		= tile_w
	self.screen_x	= screen_x
	self.screen_y	= screen_y
	self.scale		= scale
	self.dead		= false
	self.selected	= false
	self.first_move	= true

	self.x,self.y			= self:get_pos()
	self.w,self.h			= self:get_dimensions()
	self.off_x,self.off_y	= self:get_offsets()
end

function Unit:draw()
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(
		Assets[self.asset_color][self.piece],
		self.x,self.y,
		0,
		self.scale,self.scale,
		-(self.off_x)-self.w/2,
		-(self.off_y)-self.h/2
	)
end

function Unit:draw_hover(x,y)
	love.graphics.setColor(.5,1,.5,1)
	love.graphics.draw(
		Assets[self.asset_color][self.piece],
		x,y,
		0,
		self.scale,self.scale,
		self.w/2,
		self.h/2
	)
end

function Unit:move(index)
	self.index = index
	self.tile = to_xy_tile(index-1)
	self.x,self.y = self:get_pos()
	self.selected = false
	self.first_move = false
end

function Unit:kill()
	self = nil
end

function Unit:get_piece(num)
	if num == 1 then return 'pawn' end
	if num == 2 then return 'knight' end
	if num == 3 then return 'bishop' end
	if num == 4 then return 'rook' end
	if num == 5 then return 'king' end
	if num == 6 then return 'queen' end
end

function Unit:get_asset_color(num)
	if num == 1 then return 'w' else return 'b' end
end

function Unit:get_color(num)
	if num == 1 then return 1 else return 0 end
end

function Unit:get_offsets()
	if self.piece == 'pawn' then return -40/4,-250/4 end
	if self.piece == 'knight' then return -380/4,-480/4 end
	if self.piece == 'bishop' then return -550/4,-550/4 end
	if self.piece == 'rook' then return -280/4,-400/4 end
	if self.piece == 'king' then return -650/4,-680/4 end
	if self.piece == 'queen' then return -650/4,-460/4 end
end

function Unit:get_pos()
	local x = (self.tile.x-1) * self.tile_w * self.scale + (self.screen_x)
	local y = (self.tile.y-1) * self.tile_w * self.scale + (self.screen_y)

	return x,y
end

function Unit:get_dimensions()
	if self.piece == 'pawn' then return Assets.w.pawn:getWidth(),Assets.w.pawn:getHeight() end
	if self.piece == 'knight' then return Assets.w.knight:getWidth(),Assets.w.knight:getHeight() end
	if self.piece == 'bishop' then return Assets.w.bishop:getWidth(),Assets.w.bishop:getHeight() end
	if self.piece == 'rook' then return Assets.w.rook:getWidth(),Assets.w.rook:getHeight() end
	if self.piece == 'king' then return Assets.w.king:getWidth(),Assets.w.king:getHeight() end
	if self.piece == 'queen' then return Assets.w.queen:getWidth(),Assets.w.queen:getHeight() end
end

return Unit