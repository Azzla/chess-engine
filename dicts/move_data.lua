--[[
This Dictionary stores information relevant to generating legal moves in a position.
For any given square index, and a cardinal direction offset,
we can retrieve the number of squares until we've reached the edge of the board. This number
is then used to limit how many times we can multiply the direction offset for any sliding piece.
]]

local DirectionOffsets = {8,-8,1,-1,7,-7,9,-9}
local MoveData = {}

for file=1,8 do
	for rank=1,8 do
		local index = (8 * (file-1)) + rank
		
		local num_north = 8-file
		local num_south = file-1
		local num_east = 8-rank
		local num_west = rank-1

		MoveData[index] = {
			num_north,
			num_south,
			num_east,
			num_west,
			math.min(num_north, num_west),
			math.min(num_south, num_east),
			math.min(num_north, num_east),
			math.min(num_south, num_west)
		}
	end
end

return function() return MoveData,DirectionOffsets end