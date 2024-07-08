local Waft = {}
Waft.__index = Waft

local function random_dir()
	local val = love.math.random()
	local is_pos = love.math.random(1,2)
	if is_pos == 1 then return val*100 else return -val*100 end
end

function Waft:splat(text, _props)
	assert(type(text) == 'string', "First parameter must be of type 'string'.")
	local props 	= _props or {}
	local _in,_out 	= 0.5,1 --fade default values
	if props.duration then _in,_out = props.duration/2,props.duration end

	local properties =
	{
		duration	= props.duration	or 1,
		color		= props.color		or { 1,1,1,1 },
		x 			= props.x			or love.math.random(0, love.graphics.getWidth()),
		y 			= props.y			or love.math.random(0, love.graphics.getHeight()),
		dx 			= props.dx			or random_dir(), --random value between -100 and 100
		dy 			= props.dy			or random_dir(), --random value between -100 and 100
		rotation	= props.rotation	or 0,
		scale		= props.scale		or 1,
		fade		= props.fade		or { _in = _in, _out = _out}, --_in = start of the fadeout; _out = end of the fadeout.
		font		= props.font		or love.graphics.getFont()
	}
	local instance =
	{
		props		= properties,
		text 		= text,
		time		= 0,
		set = function(self, property, value) --Any property can be 'set' at runtime.
			assert(self.props[property] ~= nil, "Attempted to set an invalid property.")
			self.props[property] = value
		end,
		nudge = function(self, property, value) --Only numeric properties can be 'nudged' at runtime.
			assert(self.props[property] ~= nil, "Attempted to nudge an invalid property.")
			assert(type(self.props[property]) == 'number' and type(value) == 'number', "Attempted to nudge non-numeric property or value.")
			self.props[property] = self.props[property] + value
		end,
	}

	table.insert(self.processing, instance)
	return instance
end

--Nudge numeric property of all instances.
function Waft:nudge(property, value)
	for _,p in pairs(self.processing) do
		assert(p.props[property] ~= nil, "Attempted to nudge an invalid property.")
		assert(type(p.props[property]) == 'number' and type(value) == 'number', "Attempted to nudge non-numeric property or value.")
		p.props[property] = p.props[property] + value
	end
end

--Set property of all instances.
function Waft:set(property, value)
	for _,p in pairs(self.processing) do
		assert(p.props[property] ~= nil, "Attempted to set an invalid property.")
		p.props[property] = value
	end
end

function Waft:update(dt)
	for i,p in ipairs(self.processing) do
		p.time = p.time + dt
		if p.time >= p.props.duration then table.remove(self.processing, i) end

		--handle alpha fadeout
		if p.props.fade._out > 0 then
			if p.time >= p.props.fade._in then --start the fadeout.
				p.props.color[4] = (1 - math.min((p.time - p.props.fade._in) / (p.props.fade._out - p.props.fade._in)))
			end
		end

		p.props.x = p.props.x + (p.props.dx * dt)
		p.props.y = p.props.y + (p.props.dy * dt)
	end
end

function Waft:draw()
	--Waft does not leak any set state.
	local prev_color = {love.graphics.getColor()}
	local prev_font = love.graphics.getFont()
	for i,p in ipairs(self.processing) do
		if p.props.font then love.graphics.setFont(p.props.font) end
		love.graphics.setColor(p.props.color)
		love.graphics.print(
			p.text,
			p.props.x,
			p.props.y,
			p.props.rotation,
			p.props.scale,
			p.props.scale
		)
	end
	love.graphics.setColor(prev_color)
	love.graphics.setFont(prev_font)
end

function Waft.new()
	return setmetatable({processing = {}}, Waft)
end

return Waft.new()