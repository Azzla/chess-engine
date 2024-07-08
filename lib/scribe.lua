local Scribe = {}
Scribe.__index = Scribe

--Plays a random source from a table of love audio sources, or just a single source.
local function play_random_sound(sounds)
	if type(sounds) == 'table' then
		if #sounds == 1 then
			sounds[1]:stop()
			sounds[1]:play()
		else
			local rand_int = love.math.random(1, #sounds)
			sounds[rand_int]:stop()
			sounds[rand_int]:play()
		end
	else
		sounds:stop()
		sounds:play()
	end
end

function Scribe:write(text, _props)
	assert(type(text) == 'string', "First parameter must be of type 'string'.")
	local props = _props or {} --All parameters are optional.
	local properties =
	{
		delay		= props.delay 		or 0.1, --time in seconds between each char rendering.
		linger		= props.linger 		or 1, 	--time in seconds of how long the prompt remains after the last char is added.
		color		= props.color 		or { 1,1,1,1 },
		x 			= props.x 			or 0,
		y 			= props.y 			or 0,
		rotation	= props.rotation	or 0,
		width 		= props.width 		or love.graphics.getWidth(),
		justify 	= props.justify 	or 'left',
		scale		= props.scale 		or 1,
		sounds		= props.sounds 		or false, --in order to set this property at runtime it can't be nil.
		font		= props.font 		or love.graphics.getFont()
	}
	local instance =
	{
		props		= properties,
		text 		= text,
		draw_text	= "",
		time		= 0,
		index 		= 1, --lua moment
		set = function(self, property, value) --Any property can be 'set' at runtime.
			assert(self.props[property] ~= nil, "Attempted to set an invalid property.")
			self.props[property] = value
		end,
		nudge = function(self, property, value) --Only numeric properties can be 'nudged' at runtime.
			assert(self.props[property] ~= nil, "Attempted to nudge an invalid property.")
			assert(type(self.props[property]) == 'number' and type(value) == 'number', "Attempted to nudge non-numeric property or value.")
			self.props[property] = self.props[property] + value
		end
	}

	table.insert(self.processing, instance)
	return instance
end

--Very similar to :write, but "rolls" up the text at the end.
function Scribe:scroll(text, _props)
	local scroll = self:write(text, _props)
	scroll.waited = 0
	scroll.wait = _props.wait or 1 --defaults to 1 second of wait time.
	scroll.speed = _props.speed or scroll.props.delay --defaults to the same speed at which chars are added.
	scroll.scroll_sounds = _props.scroll_sounds or false
	scroll.removing = false
	return scroll
end

function Scribe:update(dt)
	for i,p in ipairs(self.processing) do
		p.time = p.time + dt

		--handle 'write' behavior--
		if p.time >= p.props.delay and p.index <= #p.text and not p.removing then
			local next_char = p.text:sub(p.index,p.index)
			--Don't play a sound if next_char is a space.
			if p.props.sounds and next_char:match("[^%s]") then play_random_sound(p.props.sounds) end

			p.index = p.index + 1
			p.time = 0
			p.draw_text = p.draw_text .. next_char
		elseif p.index > #p.text and p.wait then p.removing = true
		elseif p.index >= #p.text and p.time >= p.props.linger then
			--No more characters to add, and the 'linger' time is exceeded.
			table.remove(self.processing, i)
		end

		--handle 'scroll' behavior--
		if p.wait and p.removing then
			p.waited = p.waited + dt
			if p.waited >= p.wait then
				--start removing chars
				if p.time >= p.speed and p.index > 1 then
					local last_char = p.draw_text:sub(-1,-1)
					if p.scroll_sounds and last_char:match("[^%s]") then play_random_sound(p.scroll_sounds) end

					p.draw_text = p.draw_text:sub(1, -2)
					p.index = p.index - 1
					p.time = 0
				elseif p.index == 1 then
					table.remove(self.processing, i)
				end
			else p.time = 0 end
		end
	end
end

function Scribe:draw()
	--Scribe does not leak any set state.
	local prev_color = {love.graphics.getColor()}
	local prev_font = love.graphics.getFont()
	for _,p in ipairs(self.processing) do
		if p.props.font then love.graphics.setFont(p.props.font) end
		love.graphics.setColor(p.props.color)
		love.graphics.printf(
			p.draw_text,
			p.props.x,
			p.props.y,
			p.props.width / p.props.scale,
			p.props.justify,
			p.props.rotation,
			p.props.scale,
			p.props.scale
		)
	end
	love.graphics.setColor(prev_color)
	love.graphics.setFont(prev_font)
end

function Scribe.new()
	return setmetatable({processing = {}}, Scribe)
end

return Scribe.new()