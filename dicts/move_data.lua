--[[
This Dictionary stores information relevant to generating legal moves in a position.
For any given square index, and a cardinal direction offset,
we can retrieve the number of squares until we've reached the edge of the board. This number
is then used to limit how many times we can multiply the direction offset for any sliding piece.
]]
local ab_file = {1,9,17,25,33,41,49,57,2,10,18,26,34,42,50,58}
local gh_file = {7,15,23,31,39,47,55,63,8,16,24,32,40,48,56,64}

local function table_contains(table, element)
	for _, value in pairs(table) do
		if value == element then return true end
	end
	return false
end

local function wraps_board(s, target_s)
	if table_contains(ab_file, s) then
		if table_contains(gh_file, target_s) then return true end
	elseif table_contains(gh_file, s) then
		if table_contains(ab_file, target_s) then return true end
	end
	return false
end

local DirectionOffsets = {8,-8,1,-1,7,-7,9,-9}
local KnightOffsets = {6,10,15,17,-6,-10,-15,-17}
local MoveData = {}
local KnightData = {}

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
		
		KnightData[index] = {}
		for _,dir in ipairs(KnightOffsets) do
			local square_to = index+dir
			if not wraps_board(index, square_to) and square_to >=1 and square_to <=64 then
				table.insert(KnightData[index],square_to)
			end
		end
	end
end

return function() return MoveData,KnightData,DirectionOffsets end